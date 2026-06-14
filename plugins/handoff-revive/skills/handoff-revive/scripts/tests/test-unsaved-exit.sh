#!/usr/bin/env bash
# Unsaved-exit detection (feature ⑨):
#   - finalize writes .last-saved; Stop hook writes .last-turn
#   - activity after last save (beyond tolerance) → SessionStart NOTE, once
#   - saved recently → silent
#   - works even when no current.md exists (standalone note)

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
SESSION_START="$PLUGIN_DIR/hooks/session-start.sh"
STOP_HOOK="$PLUGIN_DIR/hooks/checkpoint-counter.sh"
FINALIZE="$SCRIPTS_DIR/finalize-handoff.sh"
EXAMPLE="$SKILL_DIR/templates/example.md"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p .claude/handoff
cp "$EXAMPLE" .claude/handoff/current.md

# --- markers are written by the producing scripts ---
bash "$STOP_HOOK" >/dev/null 2>&1
[ -f .claude/handoff/.last-turn ] || { echo ".last-turn not written by Stop hook"; exit 1; }
bash "$FINALIZE" .claude/handoff/current.md >/dev/null 2>&1
[ -f .claude/handoff/.last-saved ] || { echo ".last-saved not written by finalize"; exit 1; }
echo "markers: written"

# --- saved after activity (within tolerance): silent ---
out=$(echo '{"session_id":"s1"}' | bash "$SESSION_START")
if printf '%s' "$out" | grep -q 'WITHOUT saving'; then echo "unexpected unsaved note after save"; exit 1; fi
echo "saved exit: silent"

# --- activity after save beyond tolerance: NOTE fires once ---
echo "1000000" > .claude/handoff/.last-saved
echo "2000000" > .claude/handoff/.last-turn
out=$(echo '{"session_id":"s2"}' | bash "$SESSION_START")
printf '%s' "$out" | grep -q 'WITHOUT saving' || { echo "expected unsaved note, got: $out"; exit 1; }
# one-shot: marker consumed, second start silent
out=$(echo '{"session_id":"s3"}' | bash "$SESSION_START")
if printf '%s' "$out" | grep -q 'WITHOUT saving'; then echo "note should fire only once"; exit 1; fi
echo "unsaved exit: noted once"

# --- within tolerance: silent ---
echo "1000000" > .claude/handoff/.last-saved
echo "1000060" > .claude/handoff/.last-turn   # +60s < default 120s tolerance
out=$(echo '{"session_id":"s4"}' | bash "$SESSION_START")
if printf '%s' "$out" | grep -q 'WITHOUT saving'; then echo "tolerance not respected"; exit 1; fi
echo "tolerance: silent"

# --- no current.md at all: standalone note still emitted ---
rm -f .claude/handoff/current.md .claude/handoff/.last-saved
echo "2000000" > .claude/handoff/.last-turn
out=$(echo '{"session_id":"s5"}' | bash "$SESSION_START")
printf '%s' "$out" | grep -q 'WITHOUT saving' || { echo "expected standalone note, got: $out"; exit 1; }
if printf '%s' "$out" | grep -q 'handoff checkpoint exists'; then echo "should not surface missing handoff"; exit 1; fi
echo "no handoff: standalone note"

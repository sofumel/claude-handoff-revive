#!/usr/bin/env bash
# PreCompact gate + relay (feature ①, gate redesign):
#   - manual /compact with unsaved work is BLOCKED (decision:block, no marker)
#   - manual /compact when saved is allowed (marker written)
#   - auto compaction is NEVER blocked, even with unsaved work
#   - HANDOFF_COMPACT_GATE=off disables the gate
#   - on allow, the .compact-flag marker is relayed once by user-prompt-submit

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
PRE_COMPACT="$PLUGIN_DIR/hooks/pre-compact.sh"
UPS="$PLUGIN_DIR/hooks/user-prompt-submit.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p .claude/handoff

reset() { rm -f .claude/handoff/.compact-flag .claude/handoff/.last-turn \
                .claude/handoff/.last-saved .claude/handoff/.usage-flag 2>/dev/null || true; }
mark_unsaved() { echo 2000000 > .claude/handoff/.last-turn; echo 1000000 > .claude/handoff/.last-saved; }
mark_saved()   { echo 1000000 > .claude/handoff/.last-turn; echo 1000000 > .claude/handoff/.last-saved; }

# --- no markers (fresh): not enough evidence → allowed, marker written ---
reset
out=$(echo '{"trigger":"manual"}' | bash "$PRE_COMPACT")
[ -z "$out" ] || { echo "fresh manual should not block: $out"; exit 1; }
[ -f .claude/handoff/.compact-flag ] || { echo "allow should write marker"; exit 1; }
echo "fresh manual: allowed"

# --- manual + unsaved work: BLOCKED, no marker ---
reset; mark_unsaved
out=$(echo '{"trigger":"manual"}' | bash "$PRE_COMPACT")
printf '%s' "$out" | grep -q '"decision":"block"' || { echo "unsaved manual must block: $out"; exit 1; }
printf '%s' "$out" | grep -q 'handoff-revive:save' || { echo "block reason should mention save: $out"; exit 1; }
[ ! -f .claude/handoff/.compact-flag ] || { echo "blocked compact must not write marker"; exit 1; }
echo "unsaved manual: blocked"

# --- manual + saved (within tolerance): allowed ---
reset; mark_saved
out=$(echo '{"trigger":"manual"}' | bash "$PRE_COMPACT")
[ -z "$out" ] || { echo "saved manual should not block: $out"; exit 1; }
[ -f .claude/handoff/.compact-flag ] || { echo "allow should write marker"; exit 1; }
echo "saved manual: allowed"

# --- auto + unsaved: NEVER blocked ---
reset; mark_unsaved
out=$(echo '{"trigger":"auto"}' | bash "$PRE_COMPACT")
[ -z "$out" ] || { echo "auto compaction must never block: $out"; exit 1; }
[ -f .claude/handoff/.compact-flag ] || { echo "auto allow should write marker"; exit 1; }
echo "auto + unsaved: allowed (never blocks)"

# --- gate off + unsaved: allowed ---
reset; mark_unsaved
out=$(echo '{"trigger":"manual"}' | HANDOFF_COMPACT_GATE=off bash "$PRE_COMPACT")
[ -z "$out" ] || { echo "gate off should not block: $out"; exit 1; }
echo "gate off: allowed"

# --- relay: allowed marker is surfaced once by user-prompt-submit ---
reset
echo '{"trigger":"manual"}' | bash "$PRE_COMPACT" >/dev/null
out=$(echo '{}' | bash "$UPS")
printf '%s' "$out" | grep -q 'context compaction' || { echo "compact notice missing: $out"; exit 1; }
[ ! -f .claude/handoff/.compact-flag ] || { echo "marker should be consumed"; exit 1; }
out=$(echo '{}' | bash "$UPS")
[ -z "$out" ] || { echo "second prompt should be silent: $out"; exit 1; }
echo "relay: one-shot"

# --- usage flag + compact marker relayed together ---
reset
echo "AUTO_SAVE:92" > .claude/handoff/.usage-flag
echo '{"trigger":"auto"}' | bash "$PRE_COMPACT" >/dev/null
out=$(echo '{}' | bash "$UPS")
printf '%s' "$out" | grep -q '92 percent' || { echo "usage part missing: $out"; exit 1; }
printf '%s' "$out" | grep -q 'context compaction' || { echo "compact part missing: $out"; exit 1; }
echo "combined relay: OK"

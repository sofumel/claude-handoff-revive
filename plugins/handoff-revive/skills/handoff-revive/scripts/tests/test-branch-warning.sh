#!/usr/bin/env bash
# session-start.sh branch mismatch warning:
#   - handoff saved on another branch → additionalContext contains the NOTE
#   - same branch → no NOTE (but normal handoff context still present)
#   - legacy handoff without branch metadata → no NOTE

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/session-start.sh"
EXAMPLE="$SKILL_DIR/templates/example.md"
INJECT="$SCRIPTS_DIR/inject-metadata.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/repo"
cd "$WORK/repo"
git init -q -b main
git config user.name "Test"
git config user.email "t@example.com"
git commit -q --allow-empty -m init
mkdir -p .claude/handoff
cp "$EXAMPLE" .claude/handoff/current.md
bash "$INJECT" .claude/handoff/current.md   # stamps branch: "main"

# --- same branch: handoff surfaced, no branch NOTE ---
out=$(echo '{"session_id":"t1"}' | bash "$HOOK")
printf '%s' "$out" | grep -q 'handoff checkpoint exists' || { echo "expected handoff context, got: $out"; exit 1; }
if printf '%s' "$out" | grep -q 'saved on branch'; then echo "unexpected branch NOTE on same branch"; exit 1; fi
echo "same branch: no NOTE"

# --- different branch: NOTE present with both branch names ---
git checkout -q -b feature/y
out=$(echo '{"session_id":"t2"}' | bash "$HOOK")
printf '%s' "$out" | grep -q 'saved on branch \\"main\\"' || { echo "expected NOTE with saved branch, got: $out"; exit 1; }
printf '%s' "$out" | grep -q 'feature/y' || { echo "expected current branch in NOTE, got: $out"; exit 1; }
echo "different branch: NOTE emitted"

# --- legacy handoff without metadata: no NOTE ---
cp "$EXAMPLE" .claude/handoff/current.md
out=$(echo '{"session_id":"t3"}' | bash "$HOOK")
if printf '%s' "$out" | grep -q 'saved on branch'; then echo "unexpected NOTE for legacy handoff"; exit 1; fi
echo "legacy handoff: no NOTE"

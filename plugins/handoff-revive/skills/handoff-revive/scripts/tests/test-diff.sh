#!/usr/bin/env bash
# Section-wise diff (feature ⑤):
#   - default target skips the self-snapshot and compares to the previous save
#   - added/removed lines shown with +/- under their section header
#   - explicit timestamp works; unknown timestamp errors

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
FINALIZE="$SCRIPTS_DIR/finalize-handoff.sh"
DIFF="$SCRIPTS_DIR/diff-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p .claude/handoff

# save #1
cp "$EXAMPLE" .claude/handoff/current.md
bash "$FINALIZE" .claude/handoff/current.md >/dev/null 2>&1

# save #2: add a done item, change next_action (keep file:line — required by validator)
sed -e 's|^## wip|- NEWLY DONE ITEM\n## wip|' \
    -e 's|^Edit src/auth/login.ts:42 —.*|Edit src/auth/password-reset.ts:31 — apply the same safeCompare replacement.|' \
    "$EXAMPLE" > .claude/handoff/current.md
bash "$FINALIZE" .claude/handoff/current.md >/dev/null 2>&1

# --- default: compares against previous save (not the identical self-snapshot) ---
out=$(bash "$DIFF" "" .claude/handoff/current.md)
printf '%s' "$out" | grep -q '## done' || { echo "expected done section in diff: $out"; exit 1; }
printf '%s' "$out" | grep -q '+ - NEWLY DONE ITEM' || { echo "expected added done item: $out"; exit 1; }
printf '%s' "$out" | grep -q '## next_action' || { echo "expected next_action section: $out"; exit 1; }
printf '%s' "$out" | grep -q 'section(s) changed' || { echo "expected change count: $out"; exit 1; }
echo "default diff: previous save compared"

# --- explicit timestamp: oldest snapshot ---
oldest=$(ls -1 .claude/handoff/history/*.md | sort | head -1)
out=$(bash "$DIFF" "$(basename "$oldest" .md)" .claude/handoff/current.md)
printf '%s' "$out" | grep -q '+ - NEWLY DONE ITEM' || { echo "explicit timestamp diff failed: $out"; exit 1; }
echo "explicit timestamp: OK"

# --- unknown timestamp errors ---
if bash "$DIFF" 19990101T000000Z .claude/handoff/current.md >/dev/null 2>&1; then
  echo "unknown timestamp should fail"; exit 1
fi
echo "unknown timestamp: rejected"

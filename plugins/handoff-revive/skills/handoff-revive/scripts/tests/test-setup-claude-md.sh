#!/usr/bin/env bash
# CLAUDE.md guidance (feature ⑥): opt-in append, idempotent, never destructive.

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SETUP="$SCRIPTS_DIR/setup-claude-md.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

# --- appends to an existing file without touching its content ---
printf '# My project\n\nExisting durable knowledge.\n' > CLAUDE.md
bash "$SETUP" >/dev/null
grep -q '^# My project$' CLAUDE.md || { echo "existing content damaged"; exit 1; }
grep -q 'claude-handoff-revive:' CLAUDE.md || { echo "comment not appended"; exit 1; }
echo "append: existing content preserved"

# --- idempotent: second run changes nothing ---
h1=$(cksum CLAUDE.md)
out=$(bash "$SETUP")
h2=$(cksum CLAUDE.md)
[ "$h1" = "$h2" ] || { echo "second run modified the file"; exit 1; }
printf '%s' "$out" | grep -q 'already present' || { echo "expected already-present notice: $out"; exit 1; }
echo "idempotent: OK"

# --- creates the file when missing ---
rm CLAUDE.md
bash "$SETUP" >/dev/null
[ -f CLAUDE.md ] || { echo "file not created"; exit 1; }
grep -q 'claude-handoff-revive:' CLAUDE.md || { echo "comment missing in created file"; exit 1; }
echo "create: OK"

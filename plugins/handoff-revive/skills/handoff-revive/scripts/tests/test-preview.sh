#!/usr/bin/env bash
# preview-handoff.sh: shows summary + content, flags invalid files,
# and never modifies the handoff.

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
PREVIEW="$SCRIPTS_DIR/preview-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$EXAMPLE" "$WORK/h.md"
before=$(cksum "$WORK/h.md")

out=$(bash "$PREVIEW" "$WORK/h.md")
printf '%s' "$out" | grep -q 'validation: OK' || { echo "expected validation OK"; exit 1; }
printf '%s' "$out" | grep -qE '~[0-9]+ tokens' || { echo "expected token estimate"; exit 1; }
printf '%s' "$out" | grep -q '## goal' || { echo "expected content section"; exit 1; }
echo "valid file: summary + content"

after=$(cksum "$WORK/h.md")
[ "$before" = "$after" ] || { echo "preview modified the file"; exit 1; }
echo "read-only: file unchanged"

echo "garbage" > "$WORK/bad.md"
out=$(bash "$PREVIEW" "$WORK/bad.md")
printf '%s' "$out" | grep -q 'validation: INVALID' || { echo "expected INVALID flag"; exit 1; }
echo "invalid file: flagged, still exits 0"

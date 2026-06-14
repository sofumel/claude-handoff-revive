#!/usr/bin/env bash
# lessons_learned is an OPTIONAL schema section:
#   - example with the section validates
#   - removing the section entirely still validates
#   - an empty lessons_learned section is stripped by cleanup and still validates

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
VALIDATE="$SCRIPTS_DIR/validate-handoff.sh"
CLEANUP="$SCRIPTS_DIR/cleanup-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- example ships with lessons_learned and validates ---
grep -q '^## lessons_learned$' "$EXAMPLE" || { echo "example.md is missing lessons_learned"; exit 1; }
bash "$VALIDATE" "$EXAMPLE" >/dev/null
echo "with lessons_learned: accepted"

# --- removing the whole section still validates (optional) ---
awk 'BEGIN{skip=0} /^## lessons_learned$/{skip=1; next} /^## /{skip=0} !skip' "$EXAMPLE" > "$WORK/without.md"
bash "$VALIDATE" "$WORK/without.md" >/dev/null
echo "without lessons_learned: accepted"

# --- empty section is stripped by cleanup, result still validates ---
{ awk 'BEGIN{skip=0} /^## lessons_learned$/{skip=1; next} /^## /{skip=0} !skip' "$EXAMPLE"; printf '\n## lessons_learned\n'; } > "$WORK/empty.md"
bash "$CLEANUP" "$WORK/empty.md" >/dev/null 2>&1
if grep -q '^## lessons_learned$' "$WORK/empty.md"; then
  echo "empty lessons_learned should have been stripped by cleanup"
  exit 1
fi
bash "$VALIDATE" "$WORK/empty.md" >/dev/null
echo "empty section: stripped and still valid"

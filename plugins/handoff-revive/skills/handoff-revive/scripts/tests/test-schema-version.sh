#!/usr/bin/env bash
# schema_version gate in validate-handoff.sh:
#   - "1.0" (shipped example) accepted
#   - missing schema_version accepted (legacy v1.0 handoffs)
#   - non-1.x version rejected

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
VALIDATE="$SCRIPTS_DIR/validate-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- example ships with schema_version: "1.0" and passes ---
grep -q '^schema_version: "1.0"$' "$EXAMPLE" || { echo "example.md is missing schema_version"; exit 1; }
bash "$VALIDATE" "$EXAMPLE" >/dev/null
echo 'version "1.0": accepted'

# --- legacy handoff without schema_version still passes ---
grep -v '^schema_version:' "$EXAMPLE" > "$WORK/legacy.md"
bash "$VALIDATE" "$WORK/legacy.md" >/dev/null
echo "missing version (legacy): accepted"

# --- future minor version (1.5) passes ---
sed 's/^schema_version: "1.0"$/schema_version: "1.5"/' "$EXAMPLE" > "$WORK/minor.md"
bash "$VALIDATE" "$WORK/minor.md" >/dev/null
echo 'version "1.5": accepted'

# --- unsupported major version rejected ---
sed 's/^schema_version: "1.0"$/schema_version: "9.9"/' "$EXAMPLE" > "$WORK/future.md"
if bash "$VALIDATE" "$WORK/future.md" >/dev/null 2>&1; then
  echo 'version "9.9" should have been rejected'
  exit 1
fi
echo 'version "9.9": rejected as expected'

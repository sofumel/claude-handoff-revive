#!/usr/bin/env bash
# finalize-handoff.sh: combined validate+cleanup+savings call.
# Exit 0 + savings report on valid input; exit 1 on invalid input.

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
FINALIZE="$SCRIPTS_DIR/finalize-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- valid file: exit 0, savings report on stderr ---
cp "$EXAMPLE" "$WORK/fz.md"
err=$(bash "$FINALIZE" "$WORK/fz.md" 2>&1 1>/dev/null)
printf '%s' "$err" | grep -q 'Estimated savings' || { echo "missing savings report: $err"; exit 1; }
echo "valid: finalized with savings report"

# --- invalid file: exit 1 ---
echo "garbage" > "$WORK/bad.md"
if bash "$FINALIZE" "$WORK/bad.md" >/dev/null 2>&1; then
  echo "invalid input should have exited 1"
  exit 1
fi
echo "invalid: rejected as expected"

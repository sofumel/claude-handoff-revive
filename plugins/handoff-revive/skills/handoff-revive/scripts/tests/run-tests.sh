#!/usr/bin/env bash
# Local test runner: executes every test-*.sh in this directory and reports a summary.
# Pure bash, no external test framework. Exit 0 = all pass, 1 = at least one failure.
#
# Usage:
#   bash run-tests.sh             # run all tests
#   bash run-tests.sh validate    # run only test-validate.sh
#
# Tests run against the scripts in the parent directory (the working copy),
# in a temp dir, so they never touch the repository working tree.
# NOTE: this directory is dev-only — install.sh / install.ps1 exclude it.

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"

PATTERN="${1:-}"
PASS=0
FAIL=0
FAILED_NAMES=()

for t in "$DIR"/test-*.sh; do
  [ -f "$t" ] || continue
  name="$(basename "$t" .sh)"
  if [ -n "$PATTERN" ] && [[ "$name" != *"$PATTERN"* ]]; then
    continue
  fi
  printf '== %s\n' "$name"
  if output=$(bash "$t" 2>&1); then
    PASS=$((PASS + 1))
    printf '   PASS\n'
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '   FAIL\n'
    printf '%s\n' "$output" | sed 's/^/   | /'
  fi
done

TOTAL=$((PASS + FAIL))
if [ "$TOTAL" -eq 0 ]; then
  echo "No tests matched." >&2
  exit 1
fi

printf -- '----------------------------------------\n'
printf '%d/%d passed\n' "$PASS" "$TOTAL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
exit 0

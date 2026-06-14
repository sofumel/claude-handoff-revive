#!/usr/bin/env bash
# Doctor: read-only diagnostics, sane output in a healthy checkout,
# helpful WARN for an invalid handoff. Always exit 0.

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
DOCTOR="$SCRIPTS_DIR/doctor-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

# --- healthy checkout, no handoff yet ---
out=$(bash "$DOCTOR")
printf '%s' "$out" | grep -q '^PASS  git:' || { echo "git check missing: $out"; exit 1; }
printf '%s' "$out" | grep -q 'all script pairs present' || { echo "pair check failed: $out"; exit 1; }
printf '%s' "$out" | grep -q 'no current handoff' || { echo "expected no-handoff INFO: $out"; exit 1; }
echo "healthy: PASS lines present"

# --- invalid handoff -> WARN, still exit 0 ---
mkdir -p .claude/handoff
echo "garbage" > .claude/handoff/current.md
out=$(bash "$DOCTOR")
printf '%s' "$out" | grep -q 'WARN  current.md: present but INVALID' || { echo "expected INVALID warn: $out"; exit 1; }
echo "invalid handoff: WARN emitted, exit 0"

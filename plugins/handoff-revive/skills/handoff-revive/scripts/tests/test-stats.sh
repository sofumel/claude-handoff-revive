#!/usr/bin/env bash
# Stats (record/show):
#   - finalize records a save event automatically
#   - record resume appends; show aggregates with the ASSUMPTION label
#   - malformed lines are skipped; empty state has a friendly message

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
STATS="$SCRIPTS_DIR/stats-handoff.sh"
FINALIZE="$SCRIPTS_DIR/finalize-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p .claude/handoff

# --- empty state ---
out=$(bash "$STATS" show)
printf '%s' "$out" | grep -q 'no stats yet' || { echo "expected empty-state message: $out"; exit 1; }
echo "empty: friendly message"

# --- finalize records a save ---
cp "$EXAMPLE" .claude/handoff/current.md
bash "$FINALIZE" .claude/handoff/current.md >/dev/null 2>&1
grep -qE '^[0-9]+ save [0-9]+$' .claude/handoff/.stats || { echo "save event missing: $(cat .claude/handoff/.stats)"; exit 1; }
echo "finalize: save recorded"

# --- resume recorded; show aggregates ---
bash "$STATS" record resume
echo "garbage line" >> .claude/handoff/.stats
out=$(bash "$STATS" show)
printf '%s' "$out" | grep -q 'saves:   1' || { echo "save count wrong: $out"; exit 1; }
printf '%s' "$out" | grep -q 'resumes: 1' || { echo "resume count wrong: $out"; exit 1; }
printf '%s' "$out" | grep -q 'ASSUMPTION' || { echo "assumption label missing: $out"; exit 1; }
printf '%s' "$out" | grep -q 'estimated savings vs --resume' || { echo "estimate missing: $out"; exit 1; }
echo "show: counts + honest estimate"

# --- bad subcommand errors ---
if bash "$STATS" record bogus >/dev/null 2>&1; then echo "bogus kind should fail"; exit 1; fi
echo "validation: bad kind rejected"

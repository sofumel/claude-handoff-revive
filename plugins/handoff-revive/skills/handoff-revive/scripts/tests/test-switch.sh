#!/usr/bin/env bash
# Per-branch handoff switch:
#   - parks the other branch's handoff and restores this branch's parked one
#   - round-trip preserves both handoffs
#   - same branch -> no-op; no metadata -> clean error; collision -> archived

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
SWITCH="$SCRIPTS_DIR/switch-branch-handoff.sh"
INJECT="$SCRIPTS_DIR/inject-metadata.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/repo"
cd "$WORK/repo"
git init -q -b main
git config user.name T && git config user.email t@x.com
git commit -q --allow-empty -m init
mkdir -p .claude/handoff

# handoff for main
cp "$EXAMPLE" .claude/handoff/current.md
sed -i.bak 's/timing-safe な比較/MAIN HANDOFF/' .claude/handoff/current.md && rm -f .claude/handoff/current.md.bak
bash "$INJECT" .claude/handoff/current.md

# --- same branch: no-op ---
out=$(bash "$SWITCH")
printf '%s' "$out" | grep -q 'nothing to switch' || { echo "expected no-op: $out"; exit 1; }
grep -q 'MAIN HANDOFF' .claude/handoff/current.md || { echo "no-op must not move the file"; exit 1; }
echo "same branch: no-op"

# --- switch to feature/x: main handoff parked, clean slate ---
git checkout -q -b feature/x
out=$(bash "$SWITCH")
printf '%s' "$out" | grep -q 'parked the "main" handoff' || { echo "park message missing: $out"; exit 1; }
printf '%s' "$out" | grep -q 'clean slate' || { echo "clean-slate message missing: $out"; exit 1; }
[ -f .claude/handoff/branches/main.md ] || { echo "parked file missing"; exit 1; }
[ ! -f .claude/handoff/current.md ] || { echo "current should be gone (clean slate)"; exit 1; }
echo "park: main stashed, clean slate"

# --- save a feature handoff, then switch back: both survive the round-trip ---
cp "$EXAMPLE" .claude/handoff/current.md
sed -i.bak 's/timing-safe な比較/FEATURE HANDOFF/' .claude/handoff/current.md && rm -f .claude/handoff/current.md.bak
bash "$INJECT" .claude/handoff/current.md
git checkout -q main
out=$(bash "$SWITCH")
printf '%s' "$out" | grep -q 'restored the handoff parked for branch "main"' || { echo "restore message missing: $out"; exit 1; }
grep -q 'MAIN HANDOFF' .claude/handoff/current.md || { echo "main handoff not restored"; exit 1; }
grep -q 'FEATURE HANDOFF' .claude/handoff/branches/feature_x.md || { echo "feature handoff not parked (slug)"; exit 1; }
echo "round-trip: both handoffs intact (slash slugged)"

# --- no metadata: clean error ---
cp "$EXAMPLE" .claude/handoff/current.md   # no branch: field
if bash "$SWITCH" >/dev/null 2>&1; then echo "missing metadata must error"; exit 1; fi
echo "no metadata: rejected"

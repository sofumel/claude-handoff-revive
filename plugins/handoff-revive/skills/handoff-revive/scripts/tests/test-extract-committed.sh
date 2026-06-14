#!/usr/bin/env bash
# Commit-aware touched_files (feature ④):
#   - committed-only: files committed during the session are listed
#   - both: uncommitted + committed merged, deduped (porcelain reason wins)
#   - upstream exclusion: pushed commits are not listed (@{u}..HEAD)
#   - no .session-start: legacy uncommitted-only behavior

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
EXTRACT="$SCRIPTS_DIR/extract-recent-files.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/repo"
cd "$WORK/repo"
git init -q -b main
git config user.name "Test"
git config user.email "t@example.com"
mkdir -p .claude/handoff
echo "$(( $(date +%s) - 3600 ))" > .claude/handoff/.session-start

# --- committed-only ---
echo a > committed.ts
git add committed.ts
git commit -q -m c1
out=$(bash "$EXTRACT")
printf '%s' "$out" | grep -q -- '- committed.ts -- committed this session' || { echo "committed file missing: $out"; exit 1; }
echo "committed-only: listed"

# --- both + dedupe (modified file also appears in the log; porcelain reason wins) ---
echo b > uncommitted.ts
echo mod >> committed.ts
out=$(bash "$EXTRACT")
printf '%s' "$out" | grep -q -- '- uncommitted.ts -- untracked / new' || { echo "uncommitted missing: $out"; exit 1; }
printf '%s' "$out" | grep -q -- '- committed.ts -- modified' || { echo "modified reason missing: $out"; exit 1; }
n=$(printf '%s\n' "$out" | grep -c -- '- committed.ts' || true)
[ "$n" = "1" ] || { echo "committed.ts duplicated ($n): $out"; exit 1; }
echo "both: merged + deduped"

# --- upstream exclusion: pushed commits disappear from the list ---
git add -A && git commit -q -m c2
git init -q --bare "$WORK/origin.git"
git remote add origin "$WORK/origin.git"
git push -q -u origin main
echo c > local-only.ts
git add local-only.ts && git commit -q -m c3
out=$(bash "$EXTRACT")
printf '%s' "$out" | grep -q -- '- local-only.ts -- committed this session' || { echo "local-ahead commit missing: $out"; exit 1; }
if printf '%s' "$out" | grep -q -- '- committed.ts'; then echo "pushed file should be excluded: $out"; exit 1; fi
echo "upstream: pushed commits excluded"

# --- no .session-start: legacy behavior ---
rm .claude/handoff/.session-start
echo d > newfile.ts
out=$(bash "$EXTRACT")
printf '%s' "$out" | grep -q -- '- newfile.ts -- untracked / new' || { echo "untracked missing: $out"; exit 1; }
if printf '%s' "$out" | grep -q 'committed this session'; then echo "no committed scan expected without marker: $out"; exit 1; fi
echo "no marker: legacy behavior"

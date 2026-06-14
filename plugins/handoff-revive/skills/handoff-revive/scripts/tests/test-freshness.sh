#!/usr/bin/env bash
# check-freshness.sh: silent when fresh / legacy / non-git; warns on commits
# since save and on branch mismatch; "cannot verify" on unknown base_commit.
# Always exits 0 (informational, never blocks resume).

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
CHECK="$SCRIPTS_DIR/check-freshness.sh"
INJECT="$SCRIPTS_DIR/inject-metadata.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/repo"
cd "$WORK/repo"
git init -q -b main
git config user.name "Test"
git config user.email "t@example.com"
git commit -q --allow-empty -m c1
cp "$EXAMPLE" h.md
bash "$INJECT" h.md

# --- fresh (same commit, same branch): silent ---
out=$(bash "$CHECK" h.md)
[ -z "$out" ] || { echo "expected silence when fresh, got: $out"; exit 1; }
echo "fresh: silent"

# --- commits added since save: warns with count ---
git commit -q --allow-empty -m c2
git commit -q --allow-empty -m c3
out=$(bash "$CHECK" h.md)
printf '%s' "$out" | grep -q '2 commit(s) ago' || { echo "expected 2-commit warning, got: $out"; exit 1; }
echo "stale commits: warned"

# --- branch mismatch: warns ---
git checkout -q -b feature/x
out=$(bash "$CHECK" h.md)
printf '%s' "$out" | grep -q 'saved on branch "main"' || { echo "expected branch warning, got: $out"; exit 1; }
printf '%s' "$out" | grep -q '"feature/x"' || { echo "expected current branch in warning, got: $out"; exit 1; }
echo "branch mismatch: warned"

# --- unknown base_commit: cannot verify, exit 0 ---
sed -i.bak 's/^base_commit: .*/base_commit: 0123456789abcdef0123456789abcdef01234567/' h.md && rm -f h.md.bak
out=$(bash "$CHECK" h.md)
printf '%s' "$out" | grep -q 'cannot verify' || { echo "expected cannot-verify, got: $out"; exit 1; }
echo "unknown base: cannot verify"

# --- legacy handoff without metadata: silent ---
cp "$EXAMPLE" legacy.md
out=$(bash "$CHECK" legacy.md)
[ -z "$out" ] || { echo "expected silence for legacy handoff, got: $out"; exit 1; }
echo "legacy: silent"

# --- outside git: silent (handoff has metadata but no repo around) ---
mkdir -p "$WORK/nogit"
cp h.md "$WORK/nogit/h.md"
cd "$WORK/nogit"
out=$(GIT_CEILING_DIRECTORIES="$WORK" bash "$CHECK" h.md)
[ -z "$out" ] || { echo "expected silence outside git, got: $out"; exit 1; }
echo "non-git: silent"

# --- age warning fires even without git (mtime-based) ---
cp "$EXAMPLE" old.md
touch -d "10 days ago" old.md 2>/dev/null || touch -t "$(date -v-10d +%Y%m%d%H%M 2>/dev/null || echo 200001010000)" old.md
out=$(GIT_CEILING_DIRECTORIES="$WORK" bash "$CHECK" old.md)
printf '%s' "$out" | grep -q 'day(s) old' || { echo "expected age warning, got: $out"; exit 1; }
printf '%s' "$out" | grep -q 'saved_at:' || { echo "expected saved_at in warning, got: $out"; exit 1; }
echo "non-git stale: age warning"

# --- HANDOFF_STALE_DAYS=0 disables the age check ---
out=$(GIT_CEILING_DIRECTORIES="$WORK" HANDOFF_STALE_DAYS=0 bash "$CHECK" old.md)
[ -z "$out" ] || { echo "STALE_DAYS=0 should disable age check, got: $out"; exit 1; }
echo "age check: disable works"

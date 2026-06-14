#!/usr/bin/env bash
# share-to-pr.sh (feature ⑭), with a stubbed gh CLI:
#   - dry-run prints the body and posts nothing
#   - real run posts via gh pr comment with auto-detected PR number
#   - explicit PR number is used as-is
#   - no PR for branch → clean error

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
SHARE="$SCRIPTS_DIR/share-to-pr.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p .claude/handoff bin
cp "$EXAMPLE" .claude/handoff/current.md
GH_LOG="$WORK/gh.log"
export GH_LOG

# Stub gh: records invocations; "pr view" returns PR 42; "pr comment" swallows the body.
cat > bin/gh <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
case "$1 $2" in
  "pr view") [ "${GH_NO_PR:-0}" = "1" ] && exit 1; echo 42 ;;
  "pr comment") exit 0 ;;
esac
exit 0
STUB
chmod +x bin/gh
export PATH="$WORK/bin:$PATH"

# --- dry-run: body shown, gh pr comment NOT called ---
: > "$GH_LOG"
out=$(bash "$SHARE" --dry-run)
printf '%s' "$out" | grep -q 'would post the following to PR #42' || { echo "dry-run missing PR number: $out"; exit 1; }
printf '%s' "$out" | grep -q 'Handoff context' || { echo "dry-run missing body header"; exit 1; }
printf '%s' "$out" | grep -q '## goal' || { echo "dry-run missing handoff content"; exit 1; }
if grep -q 'pr comment' "$GH_LOG"; then echo "dry-run must not post"; exit 1; fi
echo "dry-run: shown, not posted"

# --- real run: posts to auto-detected PR ---
: > "$GH_LOG"
out=$(bash "$SHARE")
printf '%s' "$out" | grep -q 'posted handoff context to PR #42' || { echo "post confirmation missing: $out"; exit 1; }
grep -q 'pr comment 42 --body-file' "$GH_LOG" || { echo "gh pr comment not called: $(cat "$GH_LOG")"; exit 1; }
echo "real run: posted to auto-detected PR"

# --- explicit PR number wins ---
: > "$GH_LOG"
bash "$SHARE" 7 >/dev/null
grep -q 'pr comment 7 --body-file' "$GH_LOG" || { echo "explicit PR not used: $(cat "$GH_LOG")"; exit 1; }
echo "explicit PR: used"

# --- no PR for branch: clean error ---
if GH_NO_PR=1 bash "$SHARE" >/dev/null 2>&1; then
  echo "should fail when no PR exists"; exit 1
fi
echo "no PR: clean error"

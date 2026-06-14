#!/usr/bin/env bash
# Per-branch handoff stash/restore (zero LLM tokens). `current.md` stays the
# single active handoff; this command parks the one belonging to ANOTHER
# branch under .claude/handoff/branches/<branch>.md and restores the one for
# the branch you are on now. Never destructive: anything about to be
# overwritten is archived to history/ first.
#
# Cases (current branch = B, handoff's `branch:` metadata = SB):
#   no current.md            -> restore branches/<B>.md if parked, else no-op
#   SB missing (no metadata) -> abort with explanation (cannot route safely)
#   SB == B                  -> no-op (already the right handoff)
#   SB != B                  -> park to branches/<SB>.md, then restore
#                               branches/<B>.md if parked, else clean slate
#
# Usage:
#   switch-branch-handoff.sh

set -e

DIR=".claude/handoff"
FILE="$DIR/current.md"
BRANCHES="$DIR/branches"
SELF="$(cd "$(dirname "$0")" && pwd)"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'ERROR: not a git repository — per-branch handoffs need git.\n' >&2
  exit 1
fi
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
  printf 'ERROR: detached HEAD — check out a branch first.\n' >&2
  exit 1
fi

# Branch names may contain '/'; flatten for filenames.
slug() { printf '%s' "$1" | tr '/' '_'; }
CUR_SLUG=$(slug "$CURRENT_BRANCH")

restore_if_parked() {
  if [ -f "$BRANCHES/$CUR_SLUG.md" ]; then
    mv "$BRANCHES/$CUR_SLUG.md" "$FILE"
    printf '[handoff-revive] restored the handoff parked for branch "%s".\n' "$CURRENT_BRANCH"
  else
    printf '[handoff-revive] no handoff parked for branch "%s" — clean slate (save will create one).\n' "$CURRENT_BRANCH"
  fi
}

if [ ! -f "$FILE" ]; then
  mkdir -p "$BRANCHES"
  restore_if_parked
  exit 0
fi

SAVED_BRANCH=$(grep -m1 -E '^branch:' "$FILE" | sed -E 's/^branch:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/') || true
if [ -z "$SAVED_BRANCH" ]; then
  printf 'ERROR: current.md has no `branch:` metadata (saved before v1.1?). Cannot route it safely — re-save it on its branch first.\n' >&2
  exit 1
fi

if [ "$SAVED_BRANCH" = "$CURRENT_BRANCH" ]; then
  printf '[handoff-revive] current.md already belongs to "%s" — nothing to switch.\n' "$CURRENT_BRANCH"
  exit 0
fi

mkdir -p "$BRANCHES"
SAVED_SLUG=$(slug "$SAVED_BRANCH")

# Never destroy: if a stale parked copy exists for that branch, archive it.
if [ -f "$BRANCHES/$SAVED_SLUG.md" ]; then
  bash "$SELF/archive-current.sh" "$BRANCHES/$SAVED_SLUG.md" 2>/dev/null || true
  rm -f "$BRANCHES/$SAVED_SLUG.md"
fi
mv "$FILE" "$BRANCHES/$SAVED_SLUG.md"
printf '[handoff-revive] parked the "%s" handoff at branches/%s.md.\n' "$SAVED_BRANCH" "$SAVED_SLUG"

restore_if_parked
exit 0

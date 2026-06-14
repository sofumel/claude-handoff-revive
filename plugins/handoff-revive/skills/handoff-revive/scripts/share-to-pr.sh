#!/usr/bin/env bash
# Post the handoff as a PR comment so reviewers see the work context
# (goal / decisions / lessons_learned) next to the diff. Requires gh CLI.
#
# The body is built from a SANITIZED COPY by default (paths replaced,
# secret scan; see sanitize-handoff.sh). If likely secrets are detected the
# post is ABORTED — fix the handoff, or override with --no-sanitize.
# Sanitization is best-effort, not a security guarantee.
#
# Usage:
#   share-to-pr.sh                  # PR auto-detected from current branch
#   share-to-pr.sh 123              # explicit PR number
#   share-to-pr.sh --dry-run [123]  # print the comment body, post nothing
#   share-to-pr.sh --no-sanitize    # share the file as-is (not recommended)
#   share-to-pr.sh [123] path/to/handoff.md
#
# Exit codes: 0 posted (or dry-run shown), 1 precondition failed.

set -e

PR=""
DRY=0
SANITIZE=1
FILE=".claude/handoff/current.md"
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --no-sanitize) SANITIZE=0 ;;
    ''|*[!0-9]*) FILE="$arg" ;;
    *) PR="$arg" ;;
  esac
done

DIR_SELF="$(cd "$(dirname "$0")" && pwd)"

if ! command -v gh >/dev/null 2>&1; then
  printf 'ERROR: the GitHub CLI (gh) is required. Install: https://cli.github.com/ then run `gh auth login`.\n' >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  printf 'ERROR: handoff not found: %s — run /handoff-revive:save first.\n' "$FILE" >&2
  exit 1
fi

if [ -z "$PR" ]; then
  PR=$(gh pr view --json number --jq '.number' 2>/dev/null || true)
  if [ -z "$PR" ]; then
    printf 'ERROR: no PR found for the current branch. Pass a PR number: share-to-pr.sh <number>\n' >&2
    exit 1
  fi
fi

# Work on a sanitized COPY — the local handoff is never modified here.
SHARE_SRC=$(mktemp)
BODY=$(mktemp)
trap 'rm -f "$SHARE_SRC" "$BODY"' EXIT
cp "$FILE" "$SHARE_SRC"

if [ "$SANITIZE" = "1" ]; then
  RC=0
  bash "$DIR_SELF/sanitize-handoff.sh" "$SHARE_SRC" || RC=$?
  if [ "$RC" = "2" ]; then
    printf 'ERROR: likely secrets detected in the handoff (see warnings above). Remove them and re-save, or override with --no-sanitize at your own risk.\n' >&2
    exit 1
  elif [ "$RC" != "0" ]; then
    printf 'ERROR: sanitization failed (exit %s).\n' "$RC" >&2
    exit 1
  fi
fi

{
  printf '## 🤝 Handoff context\n\n'
  printf 'Work-state checkpoint for this branch, saved by [claude-handoff-revive](https://github.com/sofumel/claude-handoff-revive):\n\n'
  cat "$SHARE_SRC"
  printf '\n\n---\n_🤖 Posted by claude-handoff-revive (`/handoff-revive:share-to-pr`)_\n'
} > "$BODY"

# GitHub comment hard limit is 65536 chars; stay well below.
SIZE=$(wc -c < "$BODY" | tr -d ' ')
if [ "$SIZE" -gt 60000 ]; then
  printf 'ERROR: comment body is %s bytes (>60000). Trim the handoff before sharing.\n' "$SIZE" >&2
  exit 1
fi

if [ "$DRY" = "1" ]; then
  printf '[handoff-revive] dry-run: would post the following to PR #%s\n' "$PR"
  printf -- '---------------------------------------------\n'
  cat "$BODY"
  exit 0
fi

gh pr comment "$PR" --body-file "$BODY"
printf '[handoff-revive] posted handoff context to PR #%s\n' "$PR"
exit 0

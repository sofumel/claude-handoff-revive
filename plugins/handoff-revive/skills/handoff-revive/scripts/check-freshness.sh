#!/usr/bin/env bash
# Freshness check for RESUME (zero LLM tokens): compares the handoff's
# base_commit / branch metadata against the current git state.
#
# Output (stdout): human-readable warning lines, or nothing when fresh.
# Exit code: always 0 unless the handoff file itself is missing.
# This script INFORMS — it never blocks a resume.
#
# Checks:
#   - age: warns when the file is older than HANDOFF_STALE_DAYS (default 7).
#     Based on file mtime, so it works WITHOUT git. (A restore rewrites the
#     mtime, but restored-old handoffs are still caught by the commit check.)
#   - git: commits since base_commit, branch mismatch (silent when the
#     handoff has no metadata — legacy save — or outside a git repository)
#
# Usage:
#   check-freshness.sh                        # .claude/handoff/current.md
#   check-freshness.sh path/to/handoff.md

set -e

FILE="${1:-.claude/handoff/current.md}"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

# --- Age check (git-independent) ---
STALE_DAYS="${HANDOFF_STALE_DAYS:-7}"
[[ "$STALE_DAYS" =~ ^[0-9]+$ ]] || STALE_DAYS=7
if [ "$STALE_DAYS" -gt 0 ] && find "$FILE" -mtime +"$STALE_DAYS" 2>/dev/null | grep -q .; then
  SAVED_AT=$(grep -m1 -E '^saved_at:' "$FILE" | sed -E 's/^saved_at:[[:space:]]*//') || true
  printf '[handoff-revive] freshness: this handoff is more than %s day(s) old (saved_at: %s). Its contents may be outdated.\n' "$STALE_DAYS" "${SAVED_AT:-unknown}"
fi

# --- Git checks below: silent for legacy handoffs (no metadata) or outside git.
BASE_COMMIT=$(grep -m1 -E '^base_commit:' "$FILE" | sed -E 's/^base_commit:[[:space:]]*//; s/[[:space:]]+$//') || true
SAVED_BRANCH=$(grep -m1 -E '^branch:' "$FILE" | sed -E 's/^branch:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/') || true
[ -n "$BASE_COMMIT" ] || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# base_commit not present locally (rebase, shallow clone, different repo):
# report "cannot verify" but do not error.
if ! git cat-file -e "${BASE_COMMIT}^{commit}" 2>/dev/null; then
  printf '[handoff-revive] freshness: cannot verify — base_commit %.12s not found in this repository (rebased, shallow clone, or different repo).\n' "$BASE_COMMIT"
  exit 0
fi

WARNED=0

# Commits since the handoff was saved.
AHEAD=$(git rev-list --count "${BASE_COMMIT}..HEAD" 2>/dev/null || echo 0)
if [ "$AHEAD" -gt 0 ]; then
  printf '[handoff-revive] freshness: this handoff was saved %s commit(s) ago (base: %.12s). touched_files / next_action may no longer match the current code.\n' "$AHEAD" "$BASE_COMMIT"
  WARNED=1
fi

# Branch mismatch.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [ -n "$SAVED_BRANCH" ] && [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "HEAD" ] && [ "$SAVED_BRANCH" != "$CURRENT_BRANCH" ]; then
  printf '[handoff-revive] freshness: handoff was saved on branch "%s" but you are now on "%s". It may belong to different work.\n' "$SAVED_BRANCH" "$CURRENT_BRANCH"
  WARNED=1
fi

if [ "$WARNED" = "0" ]; then
  : # fresh — stay silent
fi
exit 0

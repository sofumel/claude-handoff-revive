#!/usr/bin/env bash
# Output a list of recently-changed files as `- <path> -- <reason>` lines,
# ready to drop into the `## touched_files` section of a handoff file.
#
# Strategy:
#   1. If invoked inside a git repo: use `git status --porcelain` (uncommitted changes)
#   2. Otherwise: fall back to `find -mmin -60` (last hour)
#
# Excludes vendor/build directories and dotdirs that don't represent user work.
# Caps output at 20 entries to keep the section bounded.
#
# Usage:
#   extract-recent-files.sh             # scan current directory
#   extract-recent-files.sh /path/dir   # scan given directory

set -e

DIR="${1:-.}"
cd "$DIR"

LIMIT=20

# Whitelist of dirs to ignore (anchored at repo root).
should_exclude() {
  case "$1" in
    .git|.git/*|.claude|.claude/*|node_modules|node_modules/*|dist|dist/*|build|build/*|.venv|.venv/*|__pycache__|__pycache__/*|.next|.next/*|.nuxt|.nuxt/*|.cache|.cache/*|target|target/*) return 0 ;;
    *) return 1 ;;
  esac
}

map_status() {
  case "$1" in
    "M "|" M"|MM) printf 'modified' ;;
    "A "|AM)      printf 'added' ;;
    " D"|"D ")    printf 'deleted' ;;
    "R "|RM)      printf 'renamed' ;;
    "??")         printf 'untracked / new' ;;
    *)            printf 'changed' ;;
  esac
}

emitted=0

if git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "$emitted" -ge "$LIMIT" ] && break
    status="${line:0:2}"
    path="${line:3}"
    # git porcelain wraps paths containing special chars in double quotes
    case "$path" in
      \"*\") path="${path#\"}"; path="${path%\"}" ;;
    esac
    if should_exclude "$path"; then continue; fi
    reason=$(map_status "$status")
    printf -- '- %s -- %s\n' "$path" "$reason"
    emitted=$((emitted + 1))
  done < <(git status --porcelain 2>/dev/null)
else
  # Non-git fallback: files modified in the last 60 minutes.
  while IFS= read -r f; do
    [ "$emitted" -ge "$LIMIT" ] && break
    rel="${f#./}"
    if should_exclude "$rel"; then continue; fi
    printf -- '- %s -- modified within last hour\n' "$rel"
    emitted=$((emitted + 1))
  done < <(find . -type f -mmin -60 2>/dev/null)
fi

exit 0

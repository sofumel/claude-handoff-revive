#!/usr/bin/env bash
# Output a list of recently-changed files as `- <path> -- <reason>` lines,
# ready to drop into the `## touched_files` section of a handoff file.
#
# Strategy:
#   1. If invoked inside a git repo: use `git status --porcelain` (uncommitted changes),
#      plus files committed during this session (`git log --since=<.session-start>`).
#      Pulled-in commits are excluded by limiting to @{u}..HEAD when an
#      upstream exists (local-only commits).
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
  SEEN="$(mktemp)"
  trap 'rm -f "$SEEN"' EXIT

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
    printf '%s\n' "$path" >> "$SEEN"
    emitted=$((emitted + 1))
  done < <(git status --porcelain 2>/dev/null)

  # --- files committed during this session ---
  # .session-start (epoch) is written by the SessionStart hook. When an
  # upstream exists, only local-ahead commits (@{u}..HEAD) are scanned so
  # pulled-in changes don't pollute touched_files.
  SS_FILE=".claude/handoff/.session-start"
  if [ -f "$SS_FILE" ]; then
    SS=$(tr -d '[:space:]' < "$SS_FILE" 2>/dev/null || true)
    if printf '%s' "$SS" | grep -qE '^[0-9]+$'; then
      # GNU date uses -d @epoch; BSD/macOS date uses -r epoch.
      SINCE=$(date -u -d "@$SS" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -r "$SS" '+%Y-%m-%dT%H:%M:%SZ')
      if git rev-parse '@{u}' >/dev/null 2>&1; then
        RANGE='@{u}..HEAD'
      else
        RANGE='HEAD'
      fi
      while IFS= read -r path; do
        [ -z "$path" ] && continue
        [ "$emitted" -ge "$LIMIT" ] && break
        if should_exclude "$path"; then continue; fi
        if grep -Fxq "$path" "$SEEN" 2>/dev/null; then continue; fi
        printf -- '- %s -- committed this session\n' "$path"
        printf '%s\n' "$path" >> "$SEEN"
        emitted=$((emitted + 1))
      done < <(git log --since="$SINCE" --name-only --pretty=format: --no-merges "$RANGE" 2>/dev/null | awk 'NF && !seen[$0]++')
    fi
  fi
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

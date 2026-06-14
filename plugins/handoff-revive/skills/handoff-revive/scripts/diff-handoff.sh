#!/usr/bin/env bash
# Section-wise diff between the current handoff and a history snapshot
# (zero LLM tokens). Default target: the newest snapshot whose content
# differs from current — i.e. effectively the previous save, because each
# save archives itself (the newest snapshot usually equals current).
#
# Usage:
#   diff-handoff.sh                            # current vs previous save
#   diff-handoff.sh 20260610T031500Z           # current vs that snapshot
#   diff-handoff.sh <timestamp> path/to/handoff.md

set -e

TS="${1:-}"
FILE="${2:-.claude/handoff/current.md}"
HIST_DIR="$(dirname "$FILE")/history"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

# --- resolve the snapshot to compare against ---
OLD=""
if [ -n "$TS" ]; then
  TS="${TS%.md}"
  OLD="$HIST_DIR/$TS.md"
  if [ ! -f "$OLD" ]; then
    MATCHES=$(ls -1 "$HIST_DIR"/"$TS"*.md 2>/dev/null || true)
    N=$(printf '%s\n' "$MATCHES" | grep -c . || true)
    if [ "$N" -ne 1 ]; then
      printf 'ERROR: snapshot "%s" not found or ambiguous. Run list-history.sh.\n' "$TS" >&2
      exit 1
    fi
    OLD=$(printf '%s\n' "$MATCHES" | head -1)
  fi
else
  # while-read keeps paths with spaces intact (a for-loop over $(...) would
  # word-split them).
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! cmp -s "$f" "$FILE"; then
      OLD="$f"
      break
    fi
  done < <(ls -1 "$HIST_DIR"/*.md 2>/dev/null | sort -r)
  if [ -z "$OLD" ]; then
    printf '[handoff-revive] nothing to compare: no snapshot differs from the current handoff.\n'
    exit 0
  fi
fi

get_section() {
  awk -v name="$2" '
    /^## / { on = ($0 ~ "^## " name "[[:space:]]*$") ? 1 : 0; next }
    on { print }
  ' "$1"
}

# Union of section names, in current-file order first, then old-only ones.
SECTIONS=$( { grep -E '^## ' "$FILE" || true; grep -E '^## ' "$OLD" || true; } \
  | sed -E 's/^## //; s/[[:space:]]+$//' | awk '!seen[$0]++' )

printf '[handoff-revive] diff: %s -> current (%s)\n' "$(basename "$OLD")" "$FILE"

CHANGED=0
while IFS= read -r s; do
  [ -n "$s" ] || continue
  OLD_BODY=$(get_section "$OLD" "$s")
  NEW_BODY=$(get_section "$FILE" "$s")
  [ "$OLD_BODY" = "$NEW_BODY" ] && continue
  CHANGED=$((CHANGED + 1))
  printf '## %s\n' "$s"
  # Portable diff (BSD/GNU): map "<" to "-" (removed) and ">" to "+" (added).
  diff <(printf '%s\n' "$OLD_BODY") <(printf '%s\n' "$NEW_BODY") 2>/dev/null \
    | sed -n 's/^< /  - /p; s/^> /  + /p' || true
done < <(printf '%s\n' "$SECTIONS")

if [ "$CHANGED" = "0" ]; then
  printf '  (sections identical — only frontmatter metadata differs)\n'
else
  printf '%d section(s) changed.\n' "$CHANGED"
fi
exit 0

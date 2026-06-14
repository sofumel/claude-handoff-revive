#!/usr/bin/env bash
# Snapshot the handoff into <dir>/history/<UTC-timestamp>.md (zero LLM tokens).
# Called by finalize-handoff after each successful save; safe standalone.
#
# - Collision-safe: a same-second snapshot bumps the timestamp by +1s until
#   free. Uniform digit-only names keep chronological order == lexicographic
#   order under every locale/collation (a "-2" suffix would not: '-' sorts
#   before '.' in C locale and punctuation is reordered under UTF-8 collation).
# - Count cap: keeps at most HANDOFF_HISTORY_MAX snapshots (default 200),
#   deleting the oldest. Age-based cleanup happens in the SessionStart hook
#   (HANDOFF_HISTORY_RETENTION_DAYS, default 30).
#
# Usage:
#   archive-current.sh                        # .claude/handoff/current.md
#   archive-current.sh path/to/handoff.md

set -e

FILE="${1:-.claude/handoff/current.md}"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

HIST_DIR="$(dirname "$FILE")/history"
mkdir -p "$HIST_DIR"

EPOCH=$(date +%s)
while :; do
  # GNU date uses -d @epoch; BSD/macOS date uses -r epoch.
  TS=$(date -u -d "@$EPOCH" +%Y%m%dT%H%M%SZ 2>/dev/null || date -u -r "$EPOCH" +%Y%m%dT%H%M%SZ)
  DEST="$HIST_DIR/$TS.md"
  [ -e "$DEST" ] || break
  EPOCH=$((EPOCH + 1))
done

cp "$FILE" "$DEST"
printf '[handoff-revive] snapshot: %s\n' "$DEST" >&2

# Count cap: delete oldest beyond HANDOFF_HISTORY_MAX.
MAX="${HANDOFF_HISTORY_MAX:-200}"
[[ "$MAX" =~ ^[0-9]+$ ]] || MAX=200
if [ "$MAX" -gt 0 ]; then
  COUNT=$(ls -1 "$HIST_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -gt "$MAX" ]; then
    ls -1 "$HIST_DIR"/*.md | sort | head -n $((COUNT - MAX)) | while IFS= read -r old; do
      rm -f "$old"
    done
  fi
fi

exit 0

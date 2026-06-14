#!/usr/bin/env bash
# List handoff snapshots, newest first (zero LLM tokens).
#
# Usage:
#   list-history.sh                           # .claude/handoff/history
#   list-history.sh path/to/handoff.md        # <that dir>/history

set -e

FILE="${1:-.claude/handoff/current.md}"
HIST_DIR="$(dirname "$FILE")/history"

if [ ! -d "$HIST_DIR" ] || ! ls "$HIST_DIR"/*.md >/dev/null 2>&1; then
  printf '[handoff-revive] no snapshots yet. Each save will archive one automatically.\n'
  exit 0
fi

COUNT=$(ls -1 "$HIST_DIR"/*.md | wc -l | tr -d ' ')
printf '[handoff-revive] %s snapshot(s), newest first:\n' "$COUNT"

ls -1 "$HIST_DIR"/*.md | sort -r | while IFS= read -r f; do
  name=$(basename "$f")
  size=$(wc -c < "$f" | tr -d ' ')
  goal=$(awk 'f && NF { print; exit } /^## goal[[:space:]]*$/ { f=1 }' "$f" | cut -c1-80)
  printf '  %s  %6s bytes  goal: %s\n' "$name" "$size" "${goal:-?}"
done
exit 0

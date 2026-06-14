#!/usr/bin/env bash
# Restore a snapshot as the current handoff (zero LLM tokens).
# The existing current.md is archived first, so a restore is never destructive.
#
# Usage:
#   restore-history.sh <timestamp>            # e.g. 20260610T031500Z (or with .md)
#   restore-history.sh <timestamp> path/to/handoff.md

set -e

TS="${1:-}"
FILE="${2:-.claude/handoff/current.md}"
HIST_DIR="$(dirname "$FILE")/history"

if [ -z "$TS" ]; then
  printf 'ERROR: usage: restore-history.sh <timestamp> — run list-history.sh to see snapshots.\n' >&2
  exit 1
fi
TS="${TS%.md}"

# Exact match first, then unique prefix.
SRC="$HIST_DIR/$TS.md"
if [ ! -f "$SRC" ]; then
  MATCHES=$(ls -1 "$HIST_DIR"/"$TS"*.md 2>/dev/null || true)
  N=$(printf '%s\n' "$MATCHES" | grep -c . || true)
  if [ "$N" -eq 0 ]; then
    printf 'ERROR: no snapshot matches "%s". Run list-history.sh to see what exists.\n' "$TS" >&2
    exit 1
  elif [ "$N" -gt 1 ]; then
    printf 'ERROR: "%s" is ambiguous (%s matches):\n%s\n' "$TS" "$N" "$MATCHES" >&2
    exit 1
  fi
  SRC=$(printf '%s\n' "$MATCHES" | head -1)
fi

DIR_SELF="$(cd "$(dirname "$0")" && pwd)"

# Never destroy the present: archive current.md before overwriting it.
if [ -f "$FILE" ]; then
  bash "$DIR_SELF/archive-current.sh" "$FILE" 2>/dev/null || true
fi

cp "$SRC" "$FILE"
printf '[handoff-revive] restored %s -> %s\n' "$(basename "$SRC")" "$FILE"
printf '[handoff-revive] the previous current.md was archived to history first.\n'
exit 0

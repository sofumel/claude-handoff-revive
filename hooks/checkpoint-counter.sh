#!/usr/bin/env bash
# Stop hook: increment turn counter, nudge user every N turns.
# Does NOT auto-invoke the skill (would burn tokens silently).

set -e

DIR=".claude/handoff"
COUNTER="$DIR/.turn"
THRESHOLD="${HANDOFF_CHECKPOINT_EVERY:-15}"

# Guard against non-numeric or zero values.
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -eq 0 ]; then
  THRESHOLD=15
fi

mkdir -p "$DIR"

if [ -f "$COUNTER" ]; then
  RAW=$(tr -d '[:space:]\357\273\277' < "$COUNTER")
  if [[ "$RAW" =~ ^[0-9]+$ ]]; then
    COUNT="$RAW"
  else
    COUNT=0
  fi
else
  COUNT=0
fi

COUNT=$((COUNT + 1))
printf '%s' "$COUNT" > "$COUNTER"

if [ $((COUNT % THRESHOLD)) -eq 0 ]; then
  printf '[handoff-revive] Turn %s — checkpoint due. Run /handoff to save.\n' "$COUNT" >&2
fi

exit 0

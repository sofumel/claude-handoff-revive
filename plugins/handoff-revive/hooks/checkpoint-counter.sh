#!/usr/bin/env bash
# Stop hook: record per-turn markers, and OPTIONALLY nudge the user to save.
#
# The turn-count nudge is OFF by default — it only fires when the user opts in
# by setting HANDOFF_CHECKPOINT_EVERY to a positive number (e.g. =15 nudges
# every 15 turns). Without it, this hook is silent.
#
# Always (regardless of the nudge): increments `.turn` and records `.last-turn`
# (epoch). `.last-turn` is required by the unsaved-exit detection and the
# PreCompact gate, so this hook stays installed even when the nudge is off.
# Never auto-invokes the skill (that would burn tokens silently).

set -e

DIR=".claude/handoff"
COUNTER="$DIR/.turn"

# Nudge is opt-in: enabled only when HANDOFF_CHECKPOINT_EVERY is a positive int.
NUDGE_EVERY="${HANDOFF_CHECKPOINT_EVERY:-}"
NUDGE=0
if [[ "$NUDGE_EVERY" =~ ^[0-9]+$ ]] && [ "$NUDGE_EVERY" -gt 0 ]; then
  NUDGE=1
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

# Record last-activity timestamp (epoch seconds). Used by session-start to
# detect "previous session ended without saving" and by the PreCompact gate —
# compared against the .last-saved marker written by finalize-handoff.
date +%s > "$DIR/.last-turn"

if [ "$NUDGE" = "1" ] && [ $((COUNT % NUDGE_EVERY)) -eq 0 ]; then
  printf '[handoff-revive] Turn %s — checkpoint due. Run /handoff-revive:save to save.\n' "$COUNT" >&2
fi

exit 0

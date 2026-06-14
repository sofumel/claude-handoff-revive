#!/usr/bin/env bash
# OPT-IN: append a guidance comment to CLAUDE.md so future sessions keep
# volatile work state in handoffs instead of CLAUDE.md.
#
# Never called automatically — running this script IS the user's consent.
# Idempotent: if the marker is already present, nothing is written.
# Existing content is never modified, only appended to; the file is created
# if it does not exist.
#
# Usage:
#   setup-claude-md.sh            # operates on ./CLAUDE.md
#   setup-claude-md.sh path/to/CLAUDE.md

set -e

FILE="${1:-CLAUDE.md}"
MARKER='claude-handoff-revive:'

if [ -f "$FILE" ] && grep -q "$MARKER" "$FILE"; then
  printf '[handoff-revive] guidance comment already present in %s — nothing to do.\n' "$FILE"
  exit 0
fi

BLOCK='<!-- claude-handoff-revive: For volatile work state (current task, next_action, WIP), use /handoff-revive:save instead of writing it here. CLAUDE.md is for durable project knowledge: conventions, architecture, commands. -->'

if [ -f "$FILE" ]; then
  printf '\n%s\n' "$BLOCK" >> "$FILE"
else
  printf '%s\n' "$BLOCK" > "$FILE"
fi

printf '[handoff-revive] guidance comment appended to %s\n' "$FILE"
exit 0

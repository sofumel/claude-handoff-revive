#!/usr/bin/env bash
# PostToolUse hook: monitor 5-hour usage rate.
#
# Reads rate_limits.five_hour.used_percentage from stdin JSON. When it crosses
# configurable thresholds (default 90% / 95%), writes a flag file that the
# UserPromptSubmit hook (user-prompt-submit.sh) reads to instruct Claude to
# auto-save a handoff on the next user input.
#
# Pure bash — no jq/python/node dependency. Fails silently on missing fields.
#
# Output: nothing on stdout (PostToolUse stdout would pollute Claude's context).
# State files written under .claude/handoff/:
#   .usage-flag      one-shot directive ("AUTO_SAVE:92" or "URGENT:96")
#   .last-warned     last threshold crossed (90 or 95)
#
# Environment variables:
#   HANDOFF_AUTO_SAVE_PERCENT   threshold for auto-save (default 90, "disabled" to skip)
#   HANDOFF_URGENT_PERCENT      threshold for urgent auto-save (default 95, "disabled" to skip)

set -e

DIR=".claude/handoff"
SESSIONS_DIR="$DIR/sessions"
FLAG_FILE="$DIR/.usage-flag"
LAST_WARNED_FILE="$DIR/.last-warned"

# Read all stdin (PostToolUse JSON).
INPUT=$(cat)

# --- Configuration ---
AUTO_SAVE="${HANDOFF_AUTO_SAVE_PERCENT:-90}"
URGENT="${HANDOFF_URGENT_PERCENT:-95}"

# Both disabled? Nothing to do.
if [ "$AUTO_SAVE" = "disabled" ] && [ "$URGENT" = "disabled" ]; then
  exit 0
fi

# --- Pure bash JSON field extractor ---
# Extracts integer values for nested fields (best-effort regex). Returns "0" on failure.
extract_int() {
  local pattern="$1"
  printf '%s' "$INPUT" | tr -d '\n\r' \
    | grep -oE "$pattern" | grep -oE '[0-9]+' | head -1
}

extract_string() {
  local field="$1"
  printf '%s' "$INPUT" | tr -d '\n\r' \
    | grep -oE "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed -E "s/\"$field\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"/\1/"
}

# Extract usage percentage and session id.
USAGE=$(extract_int '"five_hour"[^}]*"used_percentage"[[:space:]]*:[[:space:]]*[0-9]+')
USAGE=${USAGE:-0}

SESSION_ID=$(extract_string 'session_id')

mkdir -p "$DIR" "$SESSIONS_DIR"

# --- Per-session disable check ---
if [ -n "$SESSION_ID" ] && [ -f "$SESSIONS_DIR/$SESSION_ID.disabled" ]; then
  exit 0
fi

# --- Read last warned threshold ---
LAST_WARNED=0
if [ -f "$LAST_WARNED_FILE" ]; then
  raw=$(tr -d '[:space:]\357\273\277' < "$LAST_WARNED_FILE")
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    LAST_WARNED="$raw"
  fi
fi

# --- Reset on window reset (usage drops well below thresholds) ---
if [ "$USAGE" -lt 50 ] && [ "$LAST_WARNED" -gt 0 ]; then
  rm -f "$LAST_WARNED_FILE" "$FLAG_FILE" 2>/dev/null || true
  exit 0
fi

# --- Determine new flag to write (if usage crossed a NEW threshold) ---
NEW_FLAG=""
NEW_THRESHOLD=0

# URGENT (more critical) takes precedence.
if [ "$URGENT" != "disabled" ] && [[ "$URGENT" =~ ^[0-9]+$ ]]; then
  if [ "$USAGE" -ge "$URGENT" ] && [ "$LAST_WARNED" -lt "$URGENT" ]; then
    NEW_FLAG="URGENT:$USAGE"
    NEW_THRESHOLD="$URGENT"
  fi
fi

# AUTO_SAVE if no URGENT flag was set.
if [ -z "$NEW_FLAG" ] && [ "$AUTO_SAVE" != "disabled" ] && [[ "$AUTO_SAVE" =~ ^[0-9]+$ ]]; then
  if [ "$USAGE" -ge "$AUTO_SAVE" ] && [ "$LAST_WARNED" -lt "$AUTO_SAVE" ]; then
    NEW_FLAG="AUTO_SAVE:$USAGE"
    NEW_THRESHOLD="$AUTO_SAVE"
  fi
fi

# --- Write flag and update last_warned ---
# Order: write last_warned FIRST, then flag. Reason: if user-prompt-submit
# fires concurrently and consumes the flag, .last-warned is already updated,
# so a subsequent PostToolUse won't re-fire the same threshold.
if [ -n "$NEW_FLAG" ]; then
  printf '%s' "$NEW_THRESHOLD" > "$LAST_WARNED_FILE"
  printf '%s' "$NEW_FLAG" > "$FLAG_FILE"
fi

exit 0

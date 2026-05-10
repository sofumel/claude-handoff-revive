#!/usr/bin/env bash
# SessionStart hook:
#   1. Captures session_id to .claude/handoff/.session-id (used by other hooks/commands).
#   2. Cleans up orphaned per-session toggle files (>30 days old).
#   3. Cleans up stale .usage-flag from previous sessions.
#   4. If a recent handoff file exists, surface it via additionalContext so Claude
#      can offer to resume from it (instead of suggesting `claude --resume`).
#
# Pure bash — no python/node/jq dependency.

set -e

DIR=".claude/handoff"
FILE="$DIR/current.md"
SESSIONS_DIR="$DIR/sessions"
SESSION_ID_FILE="$DIR/.session-id"

mkdir -p "$DIR" "$SESSIONS_DIR"

# --- Read JSON input from stdin ---
INPUT=$(cat)

# --- Extract session_id (pure bash regex, no jq needed) ---
extract_field() {
  local field="$1" json="$2"
  printf '%s' "$json" | tr -d '\n\r' \
    | grep -oE "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed -E "s/\"$field\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"/\1/"
}

SESSION_ID=$(extract_field 'session_id' "$INPUT")

# --- 1. Persist session_id (used by usage-monitor, /handoff-auto command, etc.) ---
if [ -n "$SESSION_ID" ]; then
  printf '%s' "$SESSION_ID" > "$SESSION_ID_FILE"
fi

# --- 2. Clean up orphaned per-session toggle files (>30 days old) ---
find "$SESSIONS_DIR" -type f -mtime +30 -delete 2>/dev/null || true

# --- 3. Clear stale state from previous sessions ---
# .turn         — Stop hook turn counter (per-session — reset so nudge fires
#                 at turn 15 of THIS session, not turn 15 of accumulated history)
# .usage-flag   — one-shot directive (might be left over if previous session
#                 crashed before user-prompt-submit consumed it)
# .last-warned  — usage threshold band (per-session — usage % is per session
#                 from Claude's perspective, but rolling 5h from API; safest
#                 to reset)
rm -f "$DIR/.turn" "$DIR/.usage-flag" "$DIR/.last-warned" 2>/dev/null || true

# --- 4. Surface existing handoff if recent ---
if [ ! -f "$FILE" ]; then
  exit 0
fi

if find "$FILE" -mtime +7 2>/dev/null | grep -q .; then
  exit 0
fi

read -r -d '' CONTEXT <<'EOF' || true
A handoff checkpoint exists at .claude/handoff/current.md (saved within the last 7 days).

If the user wants to continue prior work, READ THAT FILE — do NOT suggest `claude --resume` or `claude -c` (those replay the entire transcript and cost 30k-200k tokens; the handoff file costs ~1-3k).

The user can resume by running the slash command `/resume-from-handoff`. If they ask to "continue" / "resume" in natural language, briefly remind them to run `/resume-from-handoff` (do NOT auto-invoke the skill on natural-language phrases — only on the slash command).
EOF

# Pure-bash JSON string encoder.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\b'/\\b}"
  s="${s//$'\f'/\\f}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "$s"
}

ESC=$(json_escape "$CONTEXT")

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$ESC"

exit 0

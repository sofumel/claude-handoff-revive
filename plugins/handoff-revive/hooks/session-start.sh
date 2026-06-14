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

# --- 1. Persist session_id (used by usage-monitor, /handoff-revive:auto command, etc.) ---
if [ -n "$SESSION_ID" ]; then
  printf '%s' "$SESSION_ID" > "$SESSION_ID_FILE"
fi

# --- 1.5 Record session start time (epoch) ---
# Used by extract-recent-files to include files committed DURING this session
# in touched_files (git status alone misses already-committed work).
date +%s > "$DIR/.session-start"

# --- 2. Clean up orphaned per-session toggle files (>30 days old) ---
find "$SESSIONS_DIR" -type f -mtime +30 -delete 2>/dev/null || true

# --- 2.5 Clean up old handoff snapshots ---
RETENTION="${HANDOFF_HISTORY_RETENTION_DAYS:-30}"
[[ "$RETENTION" =~ ^[0-9]+$ ]] || RETENTION=30
if [ "$RETENTION" -gt 0 ] && [ -d "$DIR/history" ]; then
  find "$DIR/history" -type f -name '*.md' -mtime +"$RETENTION" -delete 2>/dev/null || true
fi

# --- 3. Clear stale state from previous sessions ---
# .turn         — Stop hook turn counter (per-session — reset so nudge fires
#                 at turn 15 of THIS session, not turn 15 of accumulated history)
# .usage-flag   — one-shot directive (might be left over if previous session
#                 crashed before user-prompt-submit consumed it)
# .last-warned  — usage threshold band (per-session — usage % is per session
#                 from Claude's perspective, but rolling 5h from API; safest
#                 to reset)
rm -f "$DIR/.turn" "$DIR/.usage-flag" "$DIR/.last-warned" 2>/dev/null || true

# --- 3.5 Detect unsaved exit of the previous session ---
# .last-turn (written by the Stop hook every turn) vs .last-saved (written by
# finalize-handoff on each successful save). If the previous session's last
# activity is newer than its last save (beyond a small tolerance), it ended
# without saving. One-shot: .last-turn is consumed here so the warning fires
# only on the first session start afterwards. These two markers intentionally
# survive the per-session cleanup above (.turn is per-session; these are not).
UNSAVED_NOTE=""
TOL="${HANDOFF_UNSAVED_TOLERANCE_SECONDS:-120}"
[[ "$TOL" =~ ^[0-9]+$ ]] || TOL=120
# [ -f ] guards: a `cmd < missing-file 2>/dev/null` still leaks the SHELL's
# redirection error to stderr (the 2> applies to cmd, not to the redirection).
LAST_TURN=""
LAST_SAVED=""
[ -f "$DIR/.last-turn" ] && LAST_TURN=$(tr -d '[:space:]' < "$DIR/.last-turn" 2>/dev/null || true)
[ -f "$DIR/.last-saved" ] && LAST_SAVED=$(tr -d '[:space:]' < "$DIR/.last-saved" 2>/dev/null || true)
if [[ "$LAST_TURN" =~ ^[0-9]+$ ]]; then
  if ! [[ "$LAST_SAVED" =~ ^[0-9]+$ ]] || [ "$LAST_TURN" -gt $((LAST_SAVED + TOL)) ]; then
    UNSAVED_NOTE="NOTE: the previous session ended WITHOUT saving a handoff (there was activity after the last save). If a handoff file exists it may be stale. If the user wants to continue prior work, offer to update/rebuild the handoff after confirming the current state with them."
  fi
  rm -f "$DIR/.last-turn" 2>/dev/null || true
fi

# --- 4. Surface existing handoff if recent ---
# The handoff never expires; this window only controls whether we proactively
# remind the user at session start. Configurable via HANDOFF_SURFACE_DAYS
# (default 7). Older handoffs are still usable via /handoff-revive:resume.
SURFACE_DAYS="${HANDOFF_SURFACE_DAYS:-7}"
[[ "$SURFACE_DAYS" =~ ^[0-9]+$ ]] || SURFACE_DAYS=7
SURFACE=1
if [ ! -f "$FILE" ]; then
  SURFACE=0
elif find "$FILE" -mtime +"$SURFACE_DAYS" 2>/dev/null | grep -q .; then
  SURFACE=0
fi

CONTEXT=""
if [ "$SURFACE" = "1" ]; then
read -r -d '' CONTEXT <<'EOF' || true
A handoff checkpoint exists at .claude/handoff/current.md (saved recently).

If the user wants to continue prior work, READ THAT FILE — do NOT suggest `claude --resume` or `claude -c` (those replay your entire prior conversation, typically tens of thousands of tokens; the handoff file costs ~1-3k).

The user can resume by running the slash command `/handoff-revive:resume`. If they ask to "continue" / "resume" in natural language, briefly remind them to run `/handoff-revive:resume` (do NOT auto-invoke the skill on natural-language phrases — only on the slash command).
EOF

# --- 5. Branch mismatch warning ---
# If the handoff carries `branch:` metadata and it differs from the current
# branch, it likely belongs to different work. Inform Claude (informational
# only; legacy handoffs without metadata, non-git dirs and detached HEAD skip).
SAVED_BRANCH=$(grep -m1 -E '^branch:' "$FILE" | sed -E 's/^branch:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/') || true
if [ -n "$SAVED_BRANCH" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "HEAD" ] && [ "$SAVED_BRANCH" != "$CURRENT_BRANCH" ]; then
    CONTEXT="$CONTEXT

NOTE: the handoff was saved on branch \"$SAVED_BRANCH\" but the current branch is \"$CURRENT_BRANCH\". It may belong to different work — mention this if the user resumes, suggest /handoff-revive:switch to park it and restore this branch's own handoff, and confirm with them before overwriting it on the next save."
  fi
fi
fi  # end SURFACE

# Append the unsaved-exit note (emitted even when no handoff is surfaced).
if [ -n "$UNSAVED_NOTE" ]; then
  if [ -n "$CONTEXT" ]; then
    CONTEXT="$CONTEXT

$UNSAVED_NOTE"
  else
    CONTEXT="$UNSAVED_NOTE"
  fi
fi

if [ -z "$CONTEXT" ]; then
  exit 0
fi

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

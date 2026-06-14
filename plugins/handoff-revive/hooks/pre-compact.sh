#!/usr/bin/env bash
# PreCompact hook: GATE a MANUAL /compact when there is unsaved work, so the
# pre-compact context is never lost (saving after /compact only captures the
# already-compressed summary).
#
# Why a gate, not an auto-save: hooks cannot invoke Claude, and there is no
# inference turn at compaction time — so the hook itself cannot write a
# handoff. What it CAN do (per the PreCompact hook contract) is BLOCK the
# compaction with a reason. So: if there is unsaved work, block the manual
# /compact and tell the user to run /handoff-revive:save first.
#
# Scope and safety:
#   - MANUAL /compact only. AUTO compaction (context full) is NEVER blocked —
#     blocking it could wedge the session with no way to free context.
#   - "Unsaved work" reuses the .last-turn (Stop hook) vs .last-saved
#     (finalize) markers — identical to the unsaved-exit detection. We only
#     block on POSITIVE evidence of unsaved work; missing markers = allow.
#   - HANDOFF_COMPACT_GATE=off disables the gate entirely.
#
# On allow, a `.compact-flag` marker is written; the UserPromptSubmit hook
# relays it on the next prompt so Claude won't overwrite the pre-compact
# handoff from compressed memory.
#
# Stdin: JSON with `trigger` ("manual" | "auto").

set -e

DIR=".claude/handoff"
mkdir -p "$DIR"

INPUT=$(cat 2>/dev/null || true)
TRIGGER="unknown"
case "$INPUT" in
  *'"trigger"'*'manual'*) TRIGGER="manual" ;;
  *'"trigger"'*'auto'*)   TRIGGER="auto" ;;
esac

write_marker_and_allow() {
  printf '%s:%s' "$TRIGGER" "$(date +%s)" > "$DIR/.compact-flag"
  exit 0
}

# Gate disabled, or auto-compaction → never block.
if [ "${HANDOFF_COMPACT_GATE:-on}" = "off" ] || [ "$TRIGGER" = "auto" ]; then
  write_marker_and_allow
fi

# --- Unsaved-work detection (positive evidence only) ---
TOL="${HANDOFF_UNSAVED_TOLERANCE_SECONDS:-120}"
[[ "$TOL" =~ ^[0-9]+$ ]] || TOL=120
LAST_TURN=""
LAST_SAVED=""
[ -f "$DIR/.last-turn" ]  && LAST_TURN=$(tr -d '[:space:]' < "$DIR/.last-turn" 2>/dev/null || true)
[ -f "$DIR/.last-saved" ] && LAST_SAVED=$(tr -d '[:space:]' < "$DIR/.last-saved" 2>/dev/null || true)

UNSAVED=0
if [[ "$LAST_TURN" =~ ^[0-9]+$ ]]; then
  if ! [[ "$LAST_SAVED" =~ ^[0-9]+$ ]] || [ "$LAST_TURN" -gt $((LAST_SAVED + TOL)) ]; then
    UNSAVED=1
  fi
fi

if [ "$UNSAVED" = "0" ]; then
  write_marker_and_allow
fi

# --- Block: emit a JSON decision (parsed at exit 0 per the hook contract). ---
# Reason text is kept free of " and \ so it needs no JSON escaping.
REASON="Unsaved work detected. Run /handoff-revive:save first so the pre-compact state is preserved, then run /compact again. Set HANDOFF_COMPACT_GATE=off to disable this gate."
printf '{"decision":"block","reason":"%s"}\n' "$REASON"
exit 0

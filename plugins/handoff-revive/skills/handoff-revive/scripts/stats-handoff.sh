#!/usr/bin/env bash
# Save/resume statistics (zero LLM tokens). Records events in
# .claude/handoff/.stats (one line per event: "<epoch> <kind> <bytes>")
# and reports totals with an HONEST, assumption-labelled savings estimate.
#
# Usage:
#   stats-handoff.sh record save [file]     # called by finalize-handoff
#   stats-handoff.sh record resume [file]   # called during RESUME
#   stats-handoff.sh show                   # aggregate report
#
# The estimate compares each resume against replaying a prior transcript via
# `--resume` (typically 30k-100k tokens). That range is an ASSUMPTION and is
# printed as such — we cannot measure what --resume would have cost.

set -e

CMD="${1:-show}"
DIR=".claude/handoff"
STATS="$DIR/.stats"

case "$CMD" in
  record)
    KIND="${2:-}"
    FILE="${3:-$DIR/current.md}"
    case "$KIND" in save|resume) ;; *)
      printf 'ERROR: usage: stats-handoff.sh record save|resume [file]\n' >&2
      exit 1 ;;
    esac
    [ -f "$FILE" ] || exit 0   # nothing to measure; never block the flow
    BYTES=$(wc -c < "$FILE" | tr -d ' ')
    mkdir -p "$DIR"
    printf '%s %s %s\n' "$(date +%s)" "$KIND" "$BYTES" >> "$STATS"
    exit 0
    ;;
  show)
    if [ ! -f "$STATS" ]; then
      printf '[handoff-revive] no stats yet — they accumulate from your next save.\n'
      exit 0
    fi
    # Malformed lines are skipped (the file is plain text a user may touch).
    SAVES=0; RESUMES=0; SAVE_BYTES=0; RESUME_BYTES=0
    while read -r _ kind bytes _; do
      case "$bytes" in ''|*[!0-9]*) continue ;; esac
      case "$kind" in
        save)   SAVES=$((SAVES + 1));     SAVE_BYTES=$((SAVE_BYTES + bytes)) ;;
        resume) RESUMES=$((RESUMES + 1)); RESUME_BYTES=$((RESUME_BYTES + bytes)) ;;
      esac
    done < "$STATS"

    RESUME_TOKENS=$((RESUME_BYTES / 4))
    printf '[handoff-revive] stats\n'
    printf '  saves:   %s' "$SAVES"
    if [ "$SAVES" -gt 0 ]; then printf '  (avg handoff ~%d tokens)' "$((SAVE_BYTES / 4 / SAVES))"; fi
    printf '\n'
    printf '  resumes: %s  (total ~%d tokens loaded instead of full transcripts)\n' "$RESUMES" "$RESUME_TOKENS"
    if [ "$RESUMES" -gt 0 ]; then
      LOW=$((RESUMES * 30000 - RESUME_TOKENS))
      HIGH=$((RESUMES * 100000 - RESUME_TOKENS))
      [ "$LOW" -lt 0 ] && LOW=0
      printf '  estimated savings vs --resume: ~%d to ~%d tokens\n' "$LOW" "$HIGH"
      printf '  (ASSUMPTION: a --resume replay costs 30k-100k tokens per session; actual prior-session sizes are unknowable from here)\n'
    fi
    exit 0
    ;;
  *)
    printf 'ERROR: unknown subcommand: %s (use: record save|resume, show)\n' "$CMD" >&2
    exit 1
    ;;
esac

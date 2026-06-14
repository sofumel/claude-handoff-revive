#!/usr/bin/env bash
# finalize-handoff: validate + cleanup + savings report in a single call.
# Replaces the three-tool-call sequence (validate, cleanup, savings) used during SAVE.
#
# Usage:
#   finalize-handoff.sh                          # operate on .claude/handoff/current.md
#   finalize-handoff.sh path/to/handoff.md       # operate on given path
#
# Exit codes:
#   0  — handoff is valid and finalized; savings report on stderr.
#   1  — validation failed; error list on stderr (Claude should fix and re-call).

set -e

FILE="${1:-.claude/handoff/current.md}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# Phase 1: validate. Suppress success "OK" output but keep stderr error messages.
if ! bash "$DIR/validate-handoff.sh" "$FILE" >/dev/null; then
  exit 1
fi

# Phase 2: cleanup (in-place mutation). Stderr messages pass through to user.
bash "$DIR/cleanup-handoff.sh" "$FILE"

# Phase 2.5: inject git metadata into frontmatter (best-effort; never blocks the save).
bash "$DIR/inject-metadata.sh" "$FILE" || true

# Record last-save timestamp next to the handoff (epoch seconds). Paired with
# the Stop hook's .last-turn marker to detect unsaved session exits.
date +%s > "$(dirname "$FILE")/.last-saved" 2>/dev/null || true

# Phase 2.7: snapshot this save into history/ (best-effort; never blocks).
bash "$DIR/archive-current.sh" "$FILE" 2>/dev/null || true

# Phase 2.8: count the save for /handoff-revive:stats (best-effort).
bash "$DIR/stats-handoff.sh" record save "$FILE" 2>/dev/null || true

# Phase 3: savings report.
SIZE=$(wc -c < "$FILE" | tr -d ' ')
# Rough token estimate: bytes/4 (English-heavy underestimates CJK; we add "~").
TOKENS=$((SIZE / 4))

printf '[handoff-revive] OK Saved %s (~%d tokens).\n' "$FILE" "$TOKENS" >&2
printf '[handoff-revive] Estimated savings on next resume: tens of thousands of tokens (vs --resume replaying full prior context).\n' >&2

exit 0

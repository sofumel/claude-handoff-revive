#!/usr/bin/env bash
# Print a tiny RESUME receipt before edits begin.
# The receipt confirms the load boundary without dumping handoff contents:
# it reports metadata, section names, counts and freshness status only.
#
# Usage:
#   resume-receipt.sh                        # .claude/handoff/current.md
#   resume-receipt.sh path/to/handoff.md

set -e

FILE="${1:-.claude/handoff/current.md}"
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

value_for() {
  key="$1"
  grep -m1 -E "^${key}:" "$FILE" | sed -E "s/^${key}:[[:space:]]*//; s/^\"(.*)\"$/\1/; s/[[:space:]]+$//" || true
}

section_list=$(awk '
  /^## [A-Za-z0-9_ -]+[[:space:]]*$/ {
    sub(/^##[[:space:]]+/, "")
    sub(/[[:space:]]+$/, "")
    if (out != "") { out = out ", " }
    out = out $0
    count++
  }
  END { print out }
' "$FILE")
section_count=$(grep -c -E '^## [A-Za-z0-9_ -]+[[:space:]]*$' "$FILE" || true)
touched_count=$(awk '
  /^## touched_files[[:space:]]*$/ { in_section=1; next }
  /^## / { in_section=0 }
  in_section && /^- / { count++ }
  END { print count + 0 }
' "$FILE")
next_action_present="false"
if awk '
  /^## next_action[[:space:]]*$/ { in_section=1; next }
  /^## / { in_section=0 }
  in_section && NF { found=1 }
  END { exit(found ? 0 : 1) }
' "$FILE"; then
  next_action_present="true"
fi

saved_at="$(value_for saved_at)"
branch="$(value_for branch)"
base_commit="$(value_for base_commit)"
current_branch="unknown"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
fi

freshness_output="$(bash "$DIR/check-freshness.sh" "$FILE" 2>/dev/null || true)"
freshness_warnings=0
if [ -n "$freshness_output" ]; then
  freshness_warnings=$(printf '%s\n' "$freshness_output" | grep -c '^\[handoff-revive\] freshness:' || true)
fi

printf '[handoff-revive] resume receipt\n'
printf '  handoff: %s\n' "$FILE"
printf '  saved_at: %s\n' "${saved_at:-unknown}"
printf '  branch: saved=%s current=%s\n' "${branch:-unknown}" "$current_branch"
if [ -n "$base_commit" ]; then
  printf '  base_commit: %.12s\n' "$base_commit"
else
  printf '  base_commit: unknown\n'
fi
printf '  loaded: current.md only\n'
printf '  not_loaded: prior transcript; history snapshots; other handoff files\n'
printf '  sections_present: %s (%s)\n' "$section_count" "${section_list:-none}"
printf '  touched_files_count: %s\n' "$touched_count"
printf '  next_action_present: %s\n' "$next_action_present"
if [ "$freshness_warnings" -gt 0 ]; then
  printf '  freshness: warnings=%s (see check-freshness output)\n' "$freshness_warnings"
else
  printf '  freshness: ok\n'
fi
printf '  privacy: raw_prior_transcript_included=false; history_snapshots_included=false; handoff_body_echoed=false\n'

exit 0

#!/usr/bin/env bash
# Read-only RESUME dry-run (zero LLM tokens): shows exactly what a fresh
# session would read, plus validation result, token estimate and freshness.
# Never modifies the handoff file.
#
# Usage:
#   preview-handoff.sh                        # .claude/handoff/current.md
#   preview-handoff.sh path/to/handoff.md

set -e

FILE="${1:-.claude/handoff/current.md}"
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

SIZE=$(wc -c < "$FILE" | tr -d ' ')
TOKENS=$((SIZE / 4))

printf '[handoff-revive] preview: %s\n' "$FILE"
printf '  size: %s bytes (~%d tokens — rough estimate, model-dependent)\n' "$SIZE" "$TOKENS"

if bash "$DIR/validate-handoff.sh" "$FILE" >/dev/null 2>&1; then
  printf '  validation: OK\n'
else
  printf '  validation: INVALID — run validate-handoff.sh for the issue list\n'
fi

FRESH=$(bash "$DIR/check-freshness.sh" "$FILE" 2>/dev/null || true)
if [ -n "$FRESH" ]; then
  printf '%s\n' "$FRESH" | sed 's/^/  /'
else
  printf '  freshness: OK (current commit/branch, or no metadata to check)\n'
fi

printf -- '---- content (what a fresh session will read) ----\n'
cat "$FILE"
exit 0

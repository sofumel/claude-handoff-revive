#!/usr/bin/env bash
# Inject git metadata into the handoff YAML frontmatter (zero LLM tokens).
# Called by finalize-handoff after cleanup; can also be run standalone.
#
# Fields written: author, author_email, branch, base_commit, created_at.
#   - author / author_email / branch are double-quoted: an unquoted value
#     containing ': ' would be reparsed as a nested YAML mapping.
#   - Outside a git repo only created_at is written (best-effort, no crash).
#   - HANDOFF_HIDE_EMAIL=1 omits author_email.
# Idempotent: existing metadata lines are replaced, never duplicated.
#
# Usage:
#   inject-metadata.sh                        # .claude/handoff/current.md
#   inject-metadata.sh path/to/handoff.md

set -e

FILE="${1:-.claude/handoff/current.md}"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

# Frontmatter is required for injection; silently skip otherwise
# (validate-handoff is the one that reports missing frontmatter).
head -1 "$FILE" | grep -q '^---' || exit 0

CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
AUTHOR=""
EMAIL=""
BRANCH=""
COMMIT=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  AUTHOR=$(git config user.name 2>/dev/null || true)
  EMAIL=$(git config user.email 2>/dev/null || true)
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  COMMIT=$(git rev-parse HEAD 2>/dev/null || true)
fi

if [ "${HANDOFF_HIDE_EMAIL:-0}" = "1" ]; then
  EMAIL=""
fi

# Escape backslashes and double quotes so injected values cannot break out
# of YAML double-quoted scalars.
esc() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# Build the complete metadata block in bash and hand it to awk via ENVIRON.
# (awk -v would re-process escape sequences in the values — a name containing
# a backslash or quote would corrupt the frontmatter.)
META=""
[ -n "$AUTHOR" ] && META="${META}author: \"$(esc "$AUTHOR")\"
"
[ -n "$EMAIL" ] && META="${META}author_email: \"$(esc "$EMAIL")\"
"
[ -n "$BRANCH" ] && META="${META}branch: \"$(esc "$BRANCH")\"
"
[ -n "$COMMIT" ] && META="${META}base_commit: ${COMMIT}
"
META="${META}created_at: ${CREATED_AT}
"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

HR_META="$META" awk '
NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }
in_fm && /^---[[:space:]]*$/ {
  printf "%s", ENVIRON["HR_META"]
  in_fm = 0; print; next
}
in_fm && /^(author|author_email|branch|base_commit|created_at):/ { next }
{ print }
' "$FILE" > "$TMP"

mv "$TMP" "$FILE"
exit 0

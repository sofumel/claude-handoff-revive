#!/usr/bin/env bash
# Validate a handoff file against the schema deterministically (zero LLM tokens).
# Exit 0 = valid, 1 = invalid (errors to stderr).
#
# Usage:
#   validate-handoff.sh                        # validates .claude/handoff/current.md
#   validate-handoff.sh path/to/handoff.md     # validates given path
#
# Output:
#   stdout "OK" + exit 0      on success
#   stderr error list + exit 1 on failure

set -e

FILE="${1:-.claude/handoff/current.md}"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

# Normalize input: strip UTF-8 BOM if present (some editors add it).
# Work on a temp copy so the original file is untouched.
NORM=$(mktemp)
trap 'rm -f "$NORM"' EXIT
sed $'1s/^\xEF\xBB\xBF//' "$FILE" > "$NORM"
FILE="$NORM"

ERRORS=()

# --- Frontmatter checks ---
if ! head -1 "$FILE" | grep -q '^---'; then
  ERRORS+=("missing YAML frontmatter (file must start with '---')")
else
  # Verify a closing '---' exists before the first '## ' section header.
  awk 'NR==1 { next } /^---[[:space:]]*$/ { print "CLOSED"; exit } /^## / { print "UNCLOSED"; exit }' "$FILE" | grep -q "^CLOSED$" || \
    ERRORS+=("YAML frontmatter is not closed (need a '---' line before the first '## ' section)")
fi

if ! grep -qE '^saved_at:[[:space:]]*[^[:space:]]' "$FILE"; then
  ERRORS+=("missing or empty 'saved_at:' in frontmatter")
fi

if ! grep -qE '^lang:[[:space:]]*(ja|en|zh|zh-TW|ko|es|pt|de|fr|tr)[[:space:]]*$' "$FILE"; then
  ERRORS+=("missing or invalid 'lang:' (must be one of: ja, en, zh, zh-TW, ko, es, pt, de, fr, tr)")
fi

# --- Required sections ---
for section in goal done wip todo next_action touched_files decisions; do
  if ! grep -qE "^## ${section}[[:space:]]*$" "$FILE"; then
    ERRORS+=("missing required section: ## ${section}")
  fi
done

# --- Section content extractors ---
# Match `## name` with optional trailing whitespace (parity with the section
# presence check above, which uses `^## name[[:space:]]*$`).
get_section() {
  awk -v name="$1" '
    {
      h = $0
      sub(/[[:space:]]+$/, "", h)
      if (h == "## " name) { flag = 1; next }
    }
    /^## / { flag = 0 }
    flag { print }
  ' "$FILE"
}

# next_action: must be non-empty AND contain file:line pattern.
NEXT_ACTION=$(get_section next_action)
NEXT_ACTION_STRIPPED=$(printf '%s' "$NEXT_ACTION" | tr -d '[:space:]')
if [ -z "$NEXT_ACTION_STRIPPED" ]; then
  ERRORS+=("'next_action' section is empty — must contain executable instructions")
elif ! printf '%s' "$NEXT_ACTION" | grep -qE '[^[:space:]]+:[0-9]+'; then
  ERRORS+=("'next_action' must contain a 'file:line' pattern (e.g., 'src/foo.ts:42')")
fi

# touched_files: every "- ..." entry must contain ' -- ' separator.
TOUCHED=$(get_section touched_files)
BAD_TOUCHED=$(printf '%s\n' "$TOUCHED" | grep -E '^-[[:space:]]+\S' | grep -vE ' -- ' || true)
if [ -n "$BAD_TOUCHED" ]; then
  ERRORS+=("'touched_files' entries must use ' -- ' separator (offending lines do not contain ' -- '): $(printf '%s' "$BAD_TOUCHED" | head -1)")
fi

# Template placeholders left behind.
if grep -qE '\{[A-Za-z_][^}]*\}' "$FILE"; then
  PHS=$(grep -oE '\{[A-Za-z_][^}]*\}' "$FILE" | sort -u | tr '\n' ' ')
  ERRORS+=("leftover template placeholders: ${PHS}")
fi

# goal: non-empty.
GOAL=$(get_section goal | tr -d '[:space:]')
if [ -z "$GOAL" ]; then
  ERRORS+=("'goal' section is empty")
fi

# --- Output ---
if [ ${#ERRORS[@]} -eq 0 ]; then
  printf 'OK\n'
  exit 0
fi

printf 'INVALID (%d issue(s)):\n' "${#ERRORS[@]}" >&2
for e in "${ERRORS[@]}"; do
  printf '  - %s\n' "$e" >&2
done
exit 1

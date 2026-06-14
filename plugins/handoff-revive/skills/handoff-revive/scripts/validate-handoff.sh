#!/usr/bin/env bash
# Validate a handoff file against the schema deterministically (zero LLM tokens).
# Exit 0 = valid, 1 = invalid (errors to stderr).
#
# Usage:
#   validate-handoff.sh                        # validates .claude/handoff/current.md
#   validate-handoff.sh path/to/handoff.md     # validates given path
#   validate-handoff.sh --strict [path]        # promote reference warnings to errors
#
# Output:
#   stdout "OK" + exit 0      on success
#   stderr error list + exit 1 on failure
#   stderr warning list       reference-integrity findings (lenient mode keeps exit 0)

set -e

STRICT=0
FILE=""
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    *) FILE="$arg" ;;
  esac
done
FILE="${FILE:-.claude/handoff/current.md}"

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

# --- Schema version ---
# Missing schema_version = legacy v1.0 handoff, accepted silently (backward compat).
# Future major versions branch here; everything below is the 1.x ruleset.
SCHEMA_VERSION=$(grep -m1 -E '^schema_version:' "$FILE" | sed -E 's/^schema_version:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
if [ -n "$SCHEMA_VERSION" ] && ! printf '%s' "$SCHEMA_VERSION" | grep -qE '^1\.[0-9]+$'; then
  ERRORS+=("unsupported schema_version: ${SCHEMA_VERSION} (this validator supports 1.x)")
fi

# --- Required sections ---
# ("done" is quoted so the shell can't mistake the list item for the loop keyword.)
for section in goal "done" wip todo next_action touched_files decisions; do
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

# --- Template variant ---
# A `template:` frontmatter field switches to that template's ruleset.
# No field = default schema (unchanged). Unknown values are rejected so a
# typo can't silently skip the extra requirements.
TEMPLATE=$(grep -m1 -E '^template:' "$FILE" | sed -E 's/^template:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
if [ -n "$TEMPLATE" ]; then
  case "$TEMPLATE" in
    vacation-handover)
      HN=$(get_section handover_notes | tr -d '[:space:]')
      if [ -z "$HN" ]; then
        ERRORS+=("template 'vacation-handover' requires a non-empty '## handover_notes' section")
      fi
      ;;
    *)
      ERRORS+=("unknown template: ${TEMPLATE} (known: vacation-handover)")
      ;;
  esac
fi

# --- Reference integrity ---
# Verifies that paths referenced by the handoff exist, so an AI-hallucinated
# path can't survive into a save unnoticed. Lenient by default (warnings,
# exit stays 0); --strict promotes them to errors. Bypass for files that are
# intentionally not created yet:
#   - any line containing '# planned:' is skipped entirely
#   - a touched_files reason starting with 'planned:' skips that entry
WARNINGS=()

check_ref() {
  local raw="$1" origin="$2" p="$1"
  # shellcheck disable=SC2088  # literal "~/" CASE PATTERN by design (no expansion wanted)
  case "$p" in
    "~/"*) p="${HOME}/${p#\~/}" ;;
  esac
  if [ ! -e "$p" ]; then
    WARNINGS+=("referenced path does not exist: ${raw} (${origin}) — mark it 'planned:' if it is intentionally not created yet")
  fi
}

# touched_files: check the path part of each well-formed bullet.
while IFS= read -r line; do
  case "$line" in
    "- "*) ;;
    *) continue ;;
  esac
  body="${line#- }"
  case "$body" in
    *" -- "*) path="${body%% -- *}"; reason="${body#* -- }" ;;
    *) continue ;;   # malformed separator already reported above
  esac
  case "$reason" in
    planned:*) continue ;;
  esac
  check_ref "$path" "touched_files"
done < <(printf '%s\n' "$TOUCHED")

# next_action: check file:line tokens (path-like tokens only).
while IFS= read -r line; do
  case "$line" in
    *"# planned:"*) continue ;;
  esac
  for tok in $(printf '%s\n' "$line" | grep -oE '[A-Za-z0-9_~][A-Za-z0-9_./\\~-]*:[0-9]+' || true); do
    fp="${tok%:*}"
    case "$fp" in
      */*|*.*) check_ref "$fp" "next_action" ;;
    esac
  done
done < <(printf '%s\n' "$NEXT_ACTION")

if [ "$STRICT" = "1" ] && [ ${#WARNINGS[@]} -gt 0 ]; then
  for w in "${WARNINGS[@]}"; do
    ERRORS+=("$w")
  done
  WARNINGS=()
fi

# --- Output ---
if [ ${#WARNINGS[@]} -gt 0 ]; then
  printf 'WARNINGS (%d) — informational, save still valid:\n' "${#WARNINGS[@]}" >&2
  for w in "${WARNINGS[@]}"; do
    printf '  - %s\n' "$w" >&2
  done
fi

if [ ${#ERRORS[@]} -eq 0 ]; then
  printf 'OK\n'
  exit 0
fi

printf 'INVALID (%d issue(s)):\n' "${#ERRORS[@]}" >&2
for e in "${ERRORS[@]}"; do
  printf '  - %s\n' "$e" >&2
done
exit 1

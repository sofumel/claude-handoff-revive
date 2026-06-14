#!/usr/bin/env bash
# Post-process a handoff file (zero LLM tokens):
#   B. Prune `touched_files` bullets pointing to files that no longer exist.
#   C. Strip empty sections (## header followed by no real content).
#
# Modifies the file in place. Exit 0 even if nothing to clean.
#
# Usage:
#   cleanup-handoff.sh                              # operate on .claude/handoff/current.md
#   cleanup-handoff.sh path/to/handoff.md           # operate on given path

set -e

FILE="${1:-.claude/handoff/current.md}"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# --- Phase A: strip UTF-8 BOM if present (some editors add it). ---
if head -c 3 "$FILE" | LC_ALL=C grep -qE $'^\xEF\xBB\xBF'; then
  sed $'1s/^\xEF\xBB\xBF//' "$FILE" > "$TMP"
  mv "$TMP" "$FILE"
  TMP="$(mktemp)"
fi

# --- Phase B: prune dead touched_files entries ---
# Pure bash to avoid shell injection from awk system() with attacker-controlled paths.
# Track fenced code blocks so a literal "## foo" inside ``` ... ``` is not
# misread as a section header.
{
  in_touched=0
  in_fence=0
  pruned=0
  while IFS= read -r line || [ -n "$line" ]; do
    # Fence toggle (``` or ~~~ at start of line, optional info string).
    case "$line" in
      '```'*|'~~~'*)
        in_fence=$((1 - in_fence))
        printf '%s\n' "$line"
        continue
        ;;
    esac

    if [ "$in_fence" = "0" ]; then
      case "$line" in
        "## touched_files"|"## touched_files "*)
          in_touched=1
          printf '%s\n' "$line"
          continue
          ;;
        "## "*)
          in_touched=0
          printf '%s\n' "$line"
          continue
          ;;
      esac
    fi

    if [ "$in_touched" = "1" ] && [ "$in_fence" = "0" ]; then
      case "$line" in
        "- "*)
          body="${line#- }"
          if [[ "$body" == *" -- "* ]]; then
            path="${body%% -- *}"
          else
            path="$body"
          fi
          # Safe existence check: $path is quoted, no shell expansion.
          if [ -e "$path" ]; then
            printf '%s\n' "$line"
          else
            pruned=$((pruned + 1))
          fi
          continue
          ;;
      esac
    fi
    printf '%s\n' "$line"
  done < "$FILE"

  if [ "$pruned" -gt 0 ]; then
    printf '[cleanup-handoff] pruned %d dead entries from touched_files\n' "$pruned" >&2
  fi
} > "$TMP"

mv "$TMP" "$FILE"

# --- Phase C: strip empty sections ---
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

awk '
BEGIN {
  in_fm = 0; fm_done = 0
  in_fence = 0
  sect_buf = ""; sect_name = ""; sect_has = 0; in_sect = 0; stripped = 0
  # Required sections per the schema — never strip these even if empty.
  required["goal"] = 1; required["done"] = 1; required["wip"] = 1
  required["todo"] = 1; required["next_action"] = 1
  required["touched_files"] = 1; required["decisions"] = 1
}

# Handle YAML frontmatter (first ---...--- block at top).
NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }
in_fm && /^---[[:space:]]*$/ { in_fm = 0; fm_done = 1; print; next }
in_fm { print; next }

function flush_section() {
  if (in_sect) {
    # Always keep required sections (the validator demands them).
    # Strip non-required sections that are empty.
    if (sect_has || (sect_name in required)) {
      printf "%s", sect_buf
    } else {
      stripped++
    }
  }
  sect_buf = ""
  sect_name = ""
  sect_has = 0
  in_sect = 0
}

# Toggle code-fence state on ``` or ~~~ at line start. Lines inside a fence
# are not interpreted as section headers (avoids corrupting `## foo` snippets
# embedded in code samples).
/^(```|~~~)/ {
  in_fence = 1 - in_fence
  if (in_sect) { sect_buf = sect_buf $0 "\n"; sect_has = 1 }
  else { print }
  next
}

(!in_fence) && /^## / {
  flush_section()
  sect_buf = $0 "\n"
  sect_name = $2
  in_sect = 1
  sect_has = 0
  next
}

in_sect {
  sect_buf = sect_buf $0 "\n"
  s = $0
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
  # Real content: anything non-blank that is not just a literal "-" or "- ...".
  if (s != "" && s != "-" && s != "- ...") {
    sect_has = 1
  }
  next
}

# Pre-section content (between frontmatter and first ##): pass through.
{ print }

END {
  flush_section()
  if (stripped > 0) {
    printf "[cleanup-handoff] stripped %d empty optional section(s)\n", stripped > "/dev/stderr"
  }
}
' "$FILE" > "$TMP"

mv "$TMP" "$FILE"

exit 0

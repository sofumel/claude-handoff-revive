#!/usr/bin/env bash
# validate-handoff.sh: accepts the shipped example, rejects 7 known-invalid mutations.
# (Same case matrix as .github/workflows/ci.yml "rejects 7 invalid cases".)

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
VALIDATE="$SCRIPTS_DIR/validate-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[ -f "$EXAMPLE" ] || { echo "example.md not found: $EXAMPLE"; exit 1; }

# --- valid example passes ---
bash "$VALIDATE" "$EXAMPLE" >/dev/null
echo "valid example: accepted"

# --- 7 invalid mutations are rejected ---
for case in 1 2 3 4 5 6 7; do
  cp "$EXAMPLE" "$WORK/c.md"
  case $case in
    1) tail -n +5 "$WORK/c.md" > "$WORK/cc.md" && mv "$WORK/cc.md" "$WORK/c.md" ;;                # frontmatter gone
    2) grep -v '^## decisions' "$WORK/c.md" > "$WORK/cc.md" && mv "$WORK/cc.md" "$WORK/c.md" ;;    # required section gone
    3) sed -i.bak 's|src/auth/login.ts:42|src/auth/login.ts|' "$WORK/c.md" ;;                      # next_action loses :line
    4) sed -i.bak 's| -- | : |g' "$WORK/c.md" ;;                                                   # touched_files separator broken
    5) sed -i.bak 's|ユーザー認証|{PLACEHOLDER}|' "$WORK/c.md" ;;                                  # unfilled placeholder
    6) awk 'BEGIN{s=0} /^## goal$/{print; print ""; s=1; next} /^## /{s=0} s{next} 1' "$WORK/c.md" > "$WORK/cc.md" && mv "$WORK/cc.md" "$WORK/c.md" ;;  # empty goal
    7) head -1 "$WORK/c.md" > "$WORK/h.md" && tail -n +6 "$WORK/c.md" > "$WORK/t.md" && cat "$WORK/h.md" "$WORK/t.md" > "$WORK/c.md" ;;  # unclosed frontmatter
  esac
  rm -f "$WORK/c.md.bak"
  if bash "$VALIDATE" "$WORK/c.md" >/dev/null 2>&1; then
    echo "case $case: should have been rejected"
    exit 1
  fi
  echo "case $case: rejected as expected"
done

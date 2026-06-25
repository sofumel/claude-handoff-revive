#!/usr/bin/env bash
# Regression: a CRLF secret-patterns.txt must NOT silently disable secret
# detection. On a Windows clone with autocrlf=true the patterns file could be
# checked out with CRLF; sanitize-handoff.sh strips the trailing CR so the
# known-prefix alternation still matches. (.gitattributes also pins *.txt=lf,
# so this is belt-and-suspenders.)

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
SANITIZE_SRC="$SCRIPTS_DIR/sanitize-handoff.sh"
PATTERNS_SRC="$SCRIPTS_DIR/lib/secret-patterns.txt"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Stand up an isolated copy of the script next to a CRLF patterns file. The
# script resolves PATTERNS_FILE via its own dir, so it loads our CRLF copy.
mkdir -p "$WORK/scripts/lib"
cp "$SANITIZE_SRC" "$WORK/scripts/sanitize-handoff.sh"
awk '{ printf "%s\r\n", $0 }' "$PATTERNS_SRC" > "$WORK/scripts/lib/secret-patterns.txt"

# Sanity: the doctored patterns file really carries CR bytes.
cr=$(tr -dc '\r' < "$WORK/scripts/lib/secret-patterns.txt" | wc -c | tr -d ' ')
[ "$cr" -gt 0 ] || { echo "test bug: patterns copy is not CRLF"; exit 1; }

cp "$EXAMPLE" "$WORK/h.md"
printf '\n- config.ts -- contains sk-TESTFAKE00000000000000000000 key\n' >> "$WORK/h.md"

rc=0
err=$(bash "$WORK/scripts/sanitize-handoff.sh" "$WORK/h.md" 2>&1 1>/dev/null) || rc=$?
[ "$rc" = "2" ] || { echo "FAIL: CRLF patterns must still detect the secret (got exit $rc)"; exit 1; }
printf '%s' "$err" | grep -q 'likely secrets detected' || { echo "FAIL: warning missing: $err"; exit 1; }
echo "crlf patterns: secret still detected (exit 2)"

#!/usr/bin/env bash
# Sanitize a handoff for sharing (zero LLM tokens). BEST-EFFORT ONLY —
# this is a convenience pass, NOT a security guarantee. The user remains
# responsible for reviewing shared content.
#
# What it does:
#   1. REMOVES the `author_email:` metadata line (personal data that has no
#      business in a shared artifact; the local handoff keeps it because
#      share-to-pr operates on a temp copy).
#   2. AUTO-REPLACES machine-local paths (safe, reversible by the reader):
#        <project git root>  ->  <project-root>
#        $HOME               ->  ~
#      (both POSIX and Windows path spellings when detectable)
#   3. DETECTS likely secrets (API keys, tokens, private keys, JWTs) and
#      reports them with line numbers. It NEVER auto-replaces secrets —
#      a silently "fixed" secret breeds false confidence; rotate/remove
#      it yourself.
#
# Known NOT detected (documented boundary): generic passwords, random
# hex/base64 strings without a known prefix, secrets split across lines.
#
# Usage:
#   sanitize-handoff.sh [file]      # in-place; default .claude/handoff/current.md
#
# Exit codes:
#   0 = sanitized, no likely secrets found
#   1 = file missing
#   2 = likely secrets detected (paths still sanitized; nothing redacted)

set -e

FILE="${1:-.claude/handoff/current.md}"

if [ ! -f "$FILE" ]; then
  printf 'ERROR: file not found: %s\n' "$FILE" >&2
  exit 1
fi

# --- 1. drop author_email (personal data; never belongs in shared output) ---
TMPE=$(mktemp)
trap 'rm -f "$TMPE"' EXIT
grep -v '^author_email:' "$FILE" > "$TMPE" || true
mv "$TMPE" "$FILE"
trap - EXIT

# --- 2. path replacement (literal, via bash substitution — no regex pitfalls) ---
CONTENT=$(cat "$FILE")

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HOME_UNIX="${HOME:-}"

ROOT_WIN=""
HOME_WIN=""
if command -v cygpath >/dev/null 2>&1; then
  ROOT_WIN=$(cygpath -w "$PROJECT_ROOT" 2>/dev/null || true)
  [ -n "$HOME_UNIX" ] && HOME_WIN=$(cygpath -w "$HOME_UNIX" 2>/dev/null || true)
fi

# Most specific first: project root (both spellings + forward-slash Windows),
# then home directory.
if [ -n "$ROOT_WIN" ]; then
  ROOT_WIN_FWD=$(printf '%s' "$ROOT_WIN" | tr '\\' '/')
  CONTENT="${CONTENT//"$ROOT_WIN"/<project-root>}"
  CONTENT="${CONTENT//"$ROOT_WIN_FWD"/<project-root>}"
fi
[ -n "$PROJECT_ROOT" ] && [ "$PROJECT_ROOT" != "/" ] && CONTENT="${CONTENT//"$PROJECT_ROOT"/<project-root>}"
# NB: the tilde must go through a VARIABLE. A bare ~ in the replacement
# undergoes tilde expansion back into $HOME (bash 5), and a quoted '~'
# keeps its quotes literally on bash 3.2 (macOS). $TILDE is literal on both.
TILDE='~'
if [ -n "$HOME_WIN" ]; then
  HOME_WIN_FWD=$(printf '%s' "$HOME_WIN" | tr '\\' '/')
  CONTENT="${CONTENT//"$HOME_WIN"/$TILDE}"
  CONTENT="${CONTENT//"$HOME_WIN_FWD"/$TILDE}"
fi
[ -n "$HOME_UNIX" ] && [ "$HOME_UNIX" != "/" ] && CONTENT="${CONTENT//"$HOME_UNIX"/$TILDE}"

printf '%s\n' "$CONTENT" > "$FILE"

# --- 3. secret detection (warn-only; conservative known-prefix patterns) ---
# Patterns live in lib/secret-patterns.txt — the single source shared with
# the PowerShell twin, so the two implementations cannot drift.
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
PATTERNS_FILE="$SELF_DIR/lib/secret-patterns.txt"
if [ ! -f "$PATTERNS_FILE" ]; then
  printf 'ERROR: %s is missing — broken install.\n' "$PATTERNS_FILE" >&2
  exit 1
fi
SECRET_PATTERN=""
while IFS= read -r line; do
  line="${line%$'\r'}"   # tolerate CRLF patterns file (Windows checkout)
  case "$line" in ''|\#*) continue ;; esac
  if [ -z "$SECRET_PATTERN" ]; then
    SECRET_PATTERN="$line"
  else
    SECRET_PATTERN="$SECRET_PATTERN|$line"
  fi
done < "$PATTERNS_FILE"
SECRET_PATTERN="($SECRET_PATTERN)"

FOUND=$(grep -onE "$SECRET_PATTERN" "$FILE" 2>/dev/null || true)
if [ -n "$FOUND" ]; then
  printf '[sanitize-handoff] WARNING: likely secrets detected (NOT auto-redacted - remove or rotate them yourself):\n' >&2
  printf '%s\n' "$FOUND" | while IFS=: read -r ln match; do
    printf '  line %s: %.10s... \n' "$ln" "$match" >&2
  done
  printf '[sanitize-handoff] Detection is best-effort (known prefixes only). Generic passwords and unprefixed random strings are NOT detected.\n' >&2
  exit 2
fi

exit 0

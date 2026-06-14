#!/usr/bin/env bash
# cleanup-handoff.sh: prunes dead touched_files entries, is idempotent,
# and the cleaned file still validates.

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
CLEANUP="$SCRIPTS_DIR/cleanup-handoff.sh"
VALIDATE="$SCRIPTS_DIR/validate-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- prunes dead entries (example references files that don't exist here) ---
cp "$EXAMPLE" "$WORK/cl.md"
bash "$CLEANUP" "$WORK/cl.md" 2>&1 | grep -E 'pruned [0-9]+ dead entries' >/dev/null
echo "prune: dead entries reported"

# --- idempotent: second run does not change the file ---
cp "$EXAMPLE" "$WORK/i.md"
bash "$CLEANUP" "$WORK/i.md" >/dev/null 2>&1
h1=$(cksum "$WORK/i.md")
bash "$CLEANUP" "$WORK/i.md" >/dev/null 2>&1
h2=$(cksum "$WORK/i.md")
[ "$h1" = "$h2" ] || { echo "not idempotent: $h1 != $h2"; exit 1; }
echo "idempotent: OK"

# --- cleaned file still validates ---
bash "$VALIDATE" "$WORK/i.md" >/dev/null
echo "post-cleanup validate: OK"

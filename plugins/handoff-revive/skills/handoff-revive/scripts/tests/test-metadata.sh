#!/usr/bin/env bash
# inject-metadata.sh: git metadata lands in frontmatter, quoted, idempotent;
# outside git only created_at; HANDOFF_HIDE_EMAIL masks the email;
# the injected file still validates.

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
INJECT="$SCRIPTS_DIR/inject-metadata.sh"
VALIDATE="$SCRIPTS_DIR/validate-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- inside a git repo: all fields injected, author quoted ---
mkdir -p "$WORK/repo"
cd "$WORK/repo"
git init -q
git config user.name 'Te"st: \ User'   # ': ', '"' and '\' on purpose — must survive YAML quoting
git config user.email "t@example.com"
git commit -q --allow-empty -m init
cp "$EXAMPLE" h.md

bash "$INJECT" h.md
# Expect YAML-escaped: " -> \" and \ -> \\
grep -qF 'author: "Te\"st: \\ User"' h.md || { echo "author missing or badly escaped"; grep '^author' h.md || true; exit 1; }
grep -q '^author_email: "t@example.com"$' h.md || { echo "author_email missing"; exit 1; }
grep -q "^branch: \"$(git rev-parse --abbrev-ref HEAD)\"$" h.md || { echo "branch missing"; exit 1; }
grep -q "^base_commit: $(git rev-parse HEAD)$" h.md || { echo "base_commit missing"; exit 1; }
grep -qE '^created_at: [0-9]{4}-[0-9]{2}-[0-9]{2}T' h.md || { echo "created_at missing"; exit 1; }
echo "git repo: all fields injected"

# --- idempotent: re-running keeps exactly one of each ---
bash "$INJECT" h.md
for f in author author_email branch base_commit created_at; do
  n=$(grep -c "^$f:" h.md)
  [ "$n" = "1" ] || { echo "field $f duplicated ($n times)"; exit 1; }
done
echo "idempotent: OK"

# --- metadata stays inside frontmatter (before the closing ---) ---
awk '/^---[[:space:]]*$/ && NR>1 { exit } NR>1 { print }' h.md | grep -q '^base_commit:' \
  || { echo "metadata not inside frontmatter"; exit 1; }
echo "placement: inside frontmatter"

# --- still validates after injection ---
bash "$VALIDATE" h.md >/dev/null
echo "post-inject validate: OK"

# --- HANDOFF_HIDE_EMAIL=1 omits the email ---
cp "$EXAMPLE" h2.md
HANDOFF_HIDE_EMAIL=1 bash "$INJECT" h2.md
if grep -q '^author_email:' h2.md; then echo "email should have been hidden"; exit 1; fi
grep -q '^author:' h2.md || { echo "author should still be present"; exit 1; }
echo "HANDOFF_HIDE_EMAIL: email omitted"

# --- outside a git repo: only created_at, no crash ---
# GIT_CEILING_DIRECTORIES stops upward discovery at $WORK: even if the temp
# dir happens to live inside some repo (e.g. a git-init'ed home dir), the
# script must behave as if there is no repo.
mkdir -p "$WORK/nogit"
cd "$WORK/nogit"
cp "$EXAMPLE" h.md
GIT_CEILING_DIRECTORIES="$WORK" bash "$INJECT" h.md
grep -q '^created_at:' h.md || { echo "created_at missing outside git"; exit 1; }
if grep -qE '^(author|branch|base_commit):' h.md; then echo "git fields should be absent outside git"; exit 1; fi
echo "non-git: created_at only"

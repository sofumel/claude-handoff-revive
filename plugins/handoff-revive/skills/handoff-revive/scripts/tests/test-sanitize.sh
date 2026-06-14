#!/usr/bin/env bash
# Sanitization (feature ⑯):
#   - absolute project/home paths auto-replaced with <project-root> / ~
#   - known-prefix secrets detected (exit 2), NEVER auto-redacted
#   - documented boundary: generic strings are NOT detected (exit 0)
#   - share-to-pr aborts on secrets; --no-sanitize overrides

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
SANITIZE="$SCRIPTS_DIR/sanitize-handoff.sh"
SHARE="$SCRIPTS_DIR/share-to-pr.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/repo"
cd "$WORK/repo"
git init -q -b main
git config user.name "Test"
git config user.email "t@example.com"
git commit -q --allow-empty -m init
mkdir -p .claude/handoff
ROOT=$(git rev-parse --show-toplevel)

# --- path replacement + author_email removal ---
cp "$EXAMPLE" h.md
sed -i.bak 's/^lang: ja$/lang: ja\nauthor: "Keep Me"\nauthor_email: "private@example.com"/' h.md && rm -f h.md.bak
printf '\n- %s/src/deep.ts -- absolute project path\n- %s/other/file.ts -- home path\n' "$ROOT" "$HOME" >> h.md
bash "$SANITIZE" h.md
if grep -q '^author_email:' h.md; then echo "author_email must be stripped"; exit 1; fi
grep -q '^author: "Keep Me"$' h.md || { echo "author must be kept"; exit 1; }
echo "author_email: stripped (author kept)"
grep -q -- '- <project-root>/src/deep.ts' h.md || { echo "project root not replaced: $(grep deep.ts h.md)"; exit 1; }
grep -q -- '- ~/' h.md || { echo "home not replaced: $(grep other/file h.md)"; exit 1; }
if grep -qF "$ROOT" h.md; then echo "raw project root remains"; exit 1; fi
if grep -q '\\~' h.md; then echo "backslash-tilde leak"; exit 1; fi
echo "paths: replaced"

# --- secret detection: exit 2, warning, NOT modified ---
cp "$EXAMPLE" s.md
echo '- config.ts -- contains sk-TESTFAKE00000000000000000000 key' >> s.md
rc=0
err=$(bash "$SANITIZE" s.md 2>&1 1>/dev/null) || rc=$?
[ "$rc" = "2" ] || { echo "expected exit 2, got $rc"; exit 1; }
printf '%s' "$err" | grep -q 'likely secrets detected' || { echo "warning missing: $err"; exit 1; }
grep -q 'sk-TESTFAKE00000000000000000000' s.md || { echo "secret must NOT be auto-redacted"; exit 1; }
echo "secrets: detected, not redacted"

# --- documented boundary: generic strings are NOT detected ---
cp "$EXAMPLE" b.md
echo '- note.md -- password hunter2 and hex deadbeefcafebabe1234567890abcdef' >> b.md
bash "$SANITIZE" b.md >/dev/null 2>&1 || { echo "generic strings must not trip detection"; exit 1; }
echo "boundary: generic strings pass (documented false negative)"

# --- patterns come from lib/secret-patterns.txt (second family proves it) ---
cp "$EXAMPLE" g.md
echo '- ci.yml -- token ghp_FAKE000000000000000000000000000000' >> g.md
rc=0
bash "$SANITIZE" g.md >/dev/null 2>&1 || rc=$?
[ "$rc" = "2" ] || { echo "ghp_ pattern not detected — patterns file not read?"; exit 1; }
echo "patterns file: second family detected"

# --- share-to-pr aborts on secrets; --no-sanitize overrides ---
mkdir -p bin
GH_LOG="$WORK/gh.log"; export GH_LOG; : > "$GH_LOG"
cat > bin/gh <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
case "$1 $2" in "pr view") echo 42 ;; esac
exit 0
STUB
chmod +x bin/gh
export PATH="$WORK/repo/bin:$PATH"

cp s.md .claude/handoff/current.md
if bash "$SHARE" >/dev/null 2>&1; then echo "share must abort on secrets"; exit 1; fi
if grep -q 'pr comment' "$GH_LOG"; then echo "nothing should be posted on abort"; exit 1; fi
echo "share: aborted on secrets"

bash "$SHARE" --no-sanitize >/dev/null
grep -q 'pr comment 42' "$GH_LOG" || { echo "--no-sanitize should post: $(cat "$GH_LOG")"; exit 1; }
echo "share: --no-sanitize override works"

# --- local handoff untouched by share's sanitization copy ---
grep -q 'sk-TESTFAKE00000000000000000000' .claude/handoff/current.md || { echo "share must not modify the local handoff"; exit 1; }
echo "share: local file untouched"

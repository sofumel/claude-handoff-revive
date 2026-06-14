#!/usr/bin/env bash
# Reference integrity (feature ⑫):
#   - all referenced paths exist → OK, no warnings
#   - missing path → lenient: warning + exit 0; --strict: exit 1
#   - 'planned:' reason and '# planned:' line bypass the check

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
VALIDATE="$SCRIPTS_DIR/validate-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
cp "$EXAMPLE" h.md

# Create every path the example references.
mkdir -p src/auth tests/auth tests/integration
touch src/auth/login.ts src/auth/safe-compare.ts src/auth/password-reset.ts \
      tests/auth/safe-compare.test.ts CHANGELOG.md

# --- all refs exist: OK, no warnings ---
err=$(bash "$VALIDATE" h.md 2>&1 1>/dev/null) || { echo "validate failed: $err"; exit 1; }
if printf '%s' "$err" | grep -q 'referenced path'; then echo "unexpected warning: $err"; exit 1; fi
echo "all refs exist: clean"

# --- missing touched_files path: lenient warns, exit 0 ---
rm CHANGELOG.md
err=$(bash "$VALIDATE" h.md 2>&1 1>/dev/null) || { echo "lenient mode must keep exit 0"; exit 1; }
printf '%s' "$err" | grep -q 'referenced path does not exist: CHANGELOG.md' || { echo "expected warning, got: $err"; exit 1; }
echo "missing path (lenient): warned, exit 0"

# --- strict: missing path is an error ---
if bash "$VALIDATE" --strict h.md >/dev/null 2>&1; then
  echo "--strict should have failed"; exit 1
fi
echo "missing path (strict): rejected"

# --- 'planned:' reason bypasses even strict ---
sed -i.bak 's|- CHANGELOG.md -- .*|- CHANGELOG.md -- planned: security セクションに追記予定|' h.md && rm -f h.md.bak
bash "$VALIDATE" --strict h.md >/dev/null 2>&1 || { echo "planned: reason should bypass strict"; exit 1; }
echo "planned reason: bypassed"

# --- '# planned:' line in next_action bypasses ---
rm src/auth/login.ts
sed -i.bak 's|^Edit src/auth/login.ts:42|# planned: Edit src/auth/login.ts:42|' h.md && rm -f h.md.bak
err=$(bash "$VALIDATE" h.md 2>&1 1>/dev/null) || { echo "should still be valid"; exit 1; }
if printf '%s' "$err" | grep -q 'next_action'; then echo "planned line should bypass next_action check: $err"; exit 1; fi
echo "planned line: bypassed"

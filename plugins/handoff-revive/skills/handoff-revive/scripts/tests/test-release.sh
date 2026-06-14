#!/usr/bin/env bash
# release.sh (maintainer tool), exercised against a local bare "public":
#   - refuses bad version / dirty tree / version mismatch / missing changelog
#   - dry-run pushes nothing
#   - --push produces exactly one squash commit + tag on public/main,
#     with ROADMAP.md and release.sh excluded from the published tree

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../../../../../.." && pwd)"
RELEASE_SRC="$REPO_ROOT/release.sh"

# release.sh is a maintainer-only tool, intentionally excluded from the
# published release tree. When it isn't present (i.e. running inside a public
# release checkout), there is nothing to exercise — skip cleanly.
if [ ! -f "$RELEASE_SRC" ]; then
  echo "SKIP: release.sh not present (excluded from the published tree)"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Miniature dev repo with the required release surfaces.
mkdir -p "$WORK/dev/plugins/handoff-revive/.claude-plugin" "$WORK/dev/.claude-plugin"
cd "$WORK/dev"
git init -q -b main
git config user.name R && git config user.email r@x.com
printf '{\n  "version": "9.9.9"\n}\n' > plugins/handoff-revive/.claude-plugin/plugin.json
printf '{\n  "version": "9.9.9"\n}\n' > .claude-plugin/marketplace.json
printf '# Changelog\n\n## [9.9.9] — test\n' > CHANGELOG.md
echo "internal design doc" > ROADMAP.md
echo "the product" > product.txt
cp "$RELEASE_SRC" release.sh
git add -A && git commit -q -m dev1

# Public bare remote seeded with an initial release commit.
git init -q --bare "$WORK/public.git"
git remote add public "$WORK/public.git"
SEED=$(git commit-tree "$(git rev-parse 'HEAD^{tree}')" -m "Release v9.9.8")
git push -q public "$SEED:refs/heads/main"

# --- bad version string ---
if bash release.sh 1.2.3 >/dev/null 2>&1; then echo "bad version must fail"; exit 1; fi
echo "bad version: rejected"

# --- dirty tree ---
echo dirty > dirty.txt
if bash release.sh v9.9.9 >/dev/null 2>&1; then echo "dirty tree must fail"; exit 1; fi
rm dirty.txt
echo "dirty tree: rejected"

# --- changelog missing entry ---
sed -i.bak 's/\[9.9.9\]/[0.0.1]/' CHANGELOG.md && rm -f CHANGELOG.md.bak
git add -A && git commit -q -m nochangelog
if bash release.sh v9.9.9 >/dev/null 2>&1; then echo "missing changelog must fail"; exit 1; fi
sed -i.bak 's/\[0.0.1\]/[9.9.9]/' CHANGELOG.md && rm -f CHANGELOG.md.bak
git add -A && git commit -q -m restorechangelog
echo "missing changelog: rejected"

# --- dry-run: nothing pushed ---
before=$(git ls-remote public refs/heads/main | cut -f1)
out=$(bash release.sh v9.9.9)
printf '%s' "$out" | grep -q 'DRY-RUN' || { echo "expected dry-run notice: $out"; exit 1; }
after=$(git ls-remote public refs/heads/main | cut -f1)
[ "$before" = "$after" ] || { echo "dry-run must not push"; exit 1; }
echo "dry-run: nothing pushed"

# --- push: one squash commit + tag, dev-only files excluded ---
bash release.sh v9.9.9 --push >/dev/null
git fetch -q public
TIP=$(git rev-parse public/main)
[ "$(git log --oneline "$SEED..$TIP" | wc -l | tr -d ' ')" = "1" ] || { echo "expected exactly 1 new public commit"; exit 1; }
git log -1 --format=%s "$TIP" | grep -q '^release v9.9.9$' || { echo "wrong commit subject"; exit 1; }
git ls-tree -r --name-only "$TIP" > "$WORK/tree.txt"
grep -q '^product.txt$' "$WORK/tree.txt" || { echo "product file missing from release"; exit 1; }
if grep -qE '^(ROADMAP.md|release.sh)$' "$WORK/tree.txt"; then echo "dev-only files leaked into release"; exit 1; fi
git ls-remote --tags public "refs/tags/v9.9.9" | grep -q . || { echo "tag missing on public"; exit 1; }
echo "push: 1 squash commit + tag, dev files excluded"

# --- duplicate tag refused ---
if bash release.sh v9.9.9 --push >/dev/null 2>&1; then echo "duplicate tag must fail"; exit 1; fi
echo "duplicate tag: rejected"

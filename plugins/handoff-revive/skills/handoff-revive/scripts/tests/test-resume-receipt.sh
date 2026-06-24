#!/usr/bin/env bash
# resume-receipt.sh: reports the load boundary without echoing handoff body text.

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
RECEIPT="$SCRIPTS_DIR/resume-receipt.sh"
INJECT="$SCRIPTS_DIR/inject-metadata.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/repo"
cd "$WORK/repo"
git init -q -b main
git config user.name "Test"
git config user.email "t@example.com"
git commit -q --allow-empty -m c1
cp "$EXAMPLE" .claude-handoff.md
bash "$INJECT" .claude-handoff.md

out=$(bash "$RECEIPT" .claude-handoff.md)
printf '%s' "$out" | grep -q '\[handoff-revive\] resume receipt' || { echo "missing heading: $out"; exit 1; }
printf '%s' "$out" | grep -q 'loaded: current.md only' || { echo "missing load boundary: $out"; exit 1; }
printf '%s' "$out" | grep -q 'not_loaded: prior transcript; history snapshots; other handoff files' || { echo "missing not_loaded boundary: $out"; exit 1; }
printf '%s' "$out" | grep -q 'sections_present: .*goal' || { echo "missing section names: $out"; exit 1; }
printf '%s' "$out" | grep -q 'next_action_present: true' || { echo "missing next_action presence: $out"; exit 1; }
printf '%s' "$out" | grep -q 'freshness: ok' || { echo "expected fresh receipt: $out"; exit 1; }
printf '%s' "$out" | grep -q 'handoff_body_echoed=false' || { echo "missing privacy flag: $out"; exit 1; }

# Do not echo body content from sections; section names/metadata only.
if printf '%s' "$out" | grep -q 'ユーザー認証'; then
  echo "receipt leaked handoff body content"
  exit 1
fi

git commit -q --allow-empty -m c2
out=$(bash "$RECEIPT" .claude-handoff.md)
printf '%s' "$out" | grep -q 'freshness: warnings=1' || { echo "expected one freshness warning: $out"; exit 1; }
echo "resume receipt: ok"

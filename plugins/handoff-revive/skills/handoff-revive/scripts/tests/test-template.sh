#!/usr/bin/env bash
# Template variant (feature ⑮):
#   - template: vacation-handover + non-empty handover_notes → OK
#   - missing/empty handover_notes → INVALID
#   - unknown template value → INVALID
#   - no template field → default behavior unchanged

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
EXAMPLE="$SKILL_DIR/templates/example.md"
VALIDATE="$SCRIPTS_DIR/validate-handoff.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

make_handover() {
  # $1 = output file; adds template field + handover_notes to the example.
  sed 's/^schema_version: "1.0"$/schema_version: "1.0"\ntemplate: "vacation-handover"/' "$EXAMPLE" > "$1"
  cat >> "$1" <<'EOF2'

## handover_notes
- contact: 認証周りは @tanaka へ
- deadline: 6/20 にセキュリティレビュー提出
- watch_out: login.ts の比較ロジックはテスト無しで触らない
EOF2
}

# --- valid vacation-handover passes ---
make_handover "$WORK/v.md"
bash "$VALIDATE" "$WORK/v.md" >/dev/null 2>&1 || { echo "valid vacation-handover rejected"; exit 1; }
echo "vacation-handover: accepted"

# --- missing handover_notes: rejected ---
sed 's/^schema_version: "1.0"$/schema_version: "1.0"\ntemplate: "vacation-handover"/' "$EXAMPLE" > "$WORK/m.md"
err=$(bash "$VALIDATE" "$WORK/m.md" 2>&1 1>/dev/null) && { echo "missing handover_notes should fail"; exit 1; }
printf '%s' "$err" | grep -q 'handover_notes' || { echo "wrong error: $err"; exit 1; }
echo "missing handover_notes: rejected"

# --- unknown template: rejected ---
sed 's/^schema_version: "1.0"$/schema_version: "1.0"\ntemplate: "no-such-template"/' "$EXAMPLE" > "$WORK/u.md"
err=$(bash "$VALIDATE" "$WORK/u.md" 2>&1 1>/dev/null) && { echo "unknown template should fail"; exit 1; }
printf '%s' "$err" | grep -q 'unknown template' || { echo "wrong error: $err"; exit 1; }
echo "unknown template: rejected"

# --- no template field: default unchanged ---
bash "$VALIDATE" "$EXAMPLE" >/dev/null 2>&1 || { echo "default schema must stay valid"; exit 1; }
echo "no template field: default unchanged"

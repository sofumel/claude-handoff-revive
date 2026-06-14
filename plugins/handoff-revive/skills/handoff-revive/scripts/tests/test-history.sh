#!/usr/bin/env bash
# History archive (feature ③):
#   - each finalize snapshots into history/ (collision-safe)
#   - list-history shows snapshots newest first
#   - restore brings back an old snapshot and archives current first
#   - session-start prunes snapshots older than retention

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"
SKILL_DIR="$(dirname "$SCRIPTS_DIR")"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
EXAMPLE="$SKILL_DIR/templates/example.md"
FINALIZE="$SCRIPTS_DIR/finalize-handoff.sh"
LIST="$SCRIPTS_DIR/list-history.sh"
RESTORE="$SCRIPTS_DIR/restore-history.sh"
SESSION_START="$PLUGIN_DIR/hooks/session-start.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p .claude/handoff
HIST=.claude/handoff/history

# --- save #1 creates a snapshot ---
cp "$EXAMPLE" .claude/handoff/current.md
bash "$FINALIZE" .claude/handoff/current.md >/dev/null 2>&1
n=$(ls -1 "$HIST"/*.md | wc -l | tr -d ' ')
[ "$n" = "1" ] || { echo "expected 1 snapshot, got $n"; exit 1; }

# --- save #2 (same second is fine: timestamp bumps +1s) ---
sed 's/timing-safe な比較/SECOND SAVE MARKER/' "$EXAMPLE" > .claude/handoff/current.md
bash "$FINALIZE" .claude/handoff/current.md >/dev/null 2>&1
n=$(ls -1 "$HIST"/*.md | wc -l | tr -d ' ')
[ "$n" = "2" ] || { echo "expected 2 snapshots, got $n"; exit 1; }
echo "archive per save: OK ($n snapshots)"

# --- list shows both, newest first ---
out=$(bash "$LIST" .claude/handoff/current.md)
printf '%s' "$out" | grep -q '2 snapshot(s)' || { echo "list count wrong: $out"; exit 1; }
printf '%s' "$out" | grep -q 'goal:' || { echo "list missing goal column: $out"; exit 1; }
echo "list: OK"

# --- restore the OLDEST snapshot (original goal text) ---
oldest=$(ls -1 "$HIST"/*.md | sort | head -1)
bash "$RESTORE" "$(basename "$oldest" .md)" .claude/handoff/current.md >/dev/null
grep -q 'timing-safe な比較' .claude/handoff/current.md || { echo "restore did not bring back old content"; exit 1; }
# restore archived the pre-restore current too: 3 snapshots now
n=$(ls -1 "$HIST"/*.md | wc -l | tr -d ' ')
[ "$n" = "3" ] || { echo "expected 3 snapshots after restore, got $n"; exit 1; }
echo "restore: OK (current archived first)"

# --- unknown timestamp errors cleanly ---
if bash "$RESTORE" 19990101T000000Z .claude/handoff/current.md >/dev/null 2>&1; then
  echo "unknown timestamp should fail"; exit 1
fi
echo "unknown timestamp: rejected"

# --- same-second collision: timestamp bumps, never overwrites, uniform names ---
# Pre-fill the next ~6 seconds' names so the archive MUST hit the bump loop.
ARCHIVE="$SCRIPTS_DIR/archive-current.sh"
EPOCH=$(date +%s)
for i in 0 1 2 3 4 5; do
  TS=$(date -u -d "@$((EPOCH + i))" +%Y%m%dT%H%M%SZ 2>/dev/null || date -u -r "$((EPOCH + i))" +%Y%m%dT%H%M%SZ)
  : > "$HIST/$TS.md"
done
before=$(ls -1 "$HIST"/*.md | wc -l | tr -d ' ')
bash "$ARCHIVE" .claude/handoff/current.md 2>/dev/null
after=$(ls -1 "$HIST"/*.md | wc -l | tr -d ' ')
[ "$after" = "$((before + 1))" ] || { echo "collision archive should add exactly 1 file ($before -> $after)"; exit 1; }
bad=""
for f in "$HIST"/*.md; do
  b=$(basename "$f")
  printf '%s' "$b" | grep -qE '^[0-9]{8}T[0-9]{6}Z\.md$' || bad="$bad $b"
done
[ -z "$bad" ] || { echo "non-uniform snapshot names found:$bad"; exit 1; }
echo "collision: +1s bump, uniform names"

# --- retention: old snapshot pruned by session-start ---
old="$HIST/20000101T000000Z.md"
cp "$EXAMPLE" "$old"
touch -d "2000-01-01" "$old" 2>/dev/null || touch -t 200001010000 "$old"
echo '{"session_id":"h1"}' | bash "$SESSION_START" >/dev/null
[ ! -f "$old" ] || { echo "old snapshot should have been pruned"; exit 1; }
echo "retention: pruned"

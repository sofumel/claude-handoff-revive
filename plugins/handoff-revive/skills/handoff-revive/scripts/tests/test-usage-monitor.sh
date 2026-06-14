#!/usr/bin/env bash
# usage-monitor band logic (previously covered only by CI inline steps):
#   - below threshold: no flag
#   - crossing 90: AUTO_SAVE flag + band recorded
#   - same band again: no re-fire
#   - crossing 95 after 90: upgraded to URGENT
#   - usage <50: window reset clears the band
#   - per-session disable and env disable suppress everything

set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$(dirname "$TESTS_DIR")")"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
MON="$PLUGIN_DIR/hooks/usage-monitor.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p .claude/handoff

feed() { printf '{"session_id":"%s","rate_limits":{"five_hour":{"used_percentage":%s}}}' "$1" "$2" | bash "$MON"; }

# --- below threshold: no flag ---
feed s1 50
[ ! -f .claude/handoff/.usage-flag ] || { echo "no flag expected at 50%"; exit 1; }
echo "50%: silent"

# --- crossing 90 ---
feed s1 92
[ "$(cat .claude/handoff/.usage-flag)" = "AUTO_SAVE:92" ] || { echo "AUTO_SAVE flag wrong"; exit 1; }
[ "$(cat .claude/handoff/.last-warned)" = "90" ] || { echo "band not recorded"; exit 1; }
echo "92%: AUTO_SAVE + band 90"

# --- same band: no re-fire ---
rm -f .claude/handoff/.usage-flag
feed s1 93
[ ! -f .claude/handoff/.usage-flag ] || { echo "93% must not re-fire within band 90"; exit 1; }
echo "93%: no re-fire"

# --- crossing 95: URGENT upgrade ---
feed s1 96
[ "$(cat .claude/handoff/.usage-flag)" = "URGENT:96" ] || { echo "URGENT flag wrong"; exit 1; }
[ "$(cat .claude/handoff/.last-warned)" = "95" ] || { echo "band not upgraded"; exit 1; }
echo "96%: URGENT + band 95"

# --- window reset ---
feed s1 30
[ ! -f .claude/handoff/.last-warned ] || { echo "reset must clear band"; exit 1; }
[ ! -f .claude/handoff/.usage-flag ] || { echo "reset must clear flag"; exit 1; }
echo "30%: window reset"

# --- per-session disable ---
mkdir -p .claude/handoff/sessions
touch .claude/handoff/sessions/s2.disabled
feed s2 92
[ ! -f .claude/handoff/.usage-flag ] || { echo "disabled session must not flag"; exit 1; }
echo "session disable: respected"

# --- env disable ---
printf '{"session_id":"s3","rate_limits":{"five_hour":{"used_percentage":98}}}' \
  | HANDOFF_AUTO_SAVE_PERCENT=disabled HANDOFF_URGENT_PERCENT=disabled bash "$MON"
[ ! -f .claude/handoff/.usage-flag ] || { echo "env disable must not flag"; exit 1; }
echo "env disable: respected"

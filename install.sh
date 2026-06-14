#!/usr/bin/env bash
# Standalone installer for users who can't / don't want to use `/plugin install`.
# Copies the skill, slash commands, and hooks into a Claude Code config directory.
#
# Usage:
#   ./install.sh                # install into ./.claude (current project)
#   ./install.sh --global       # install into ~/.claude (all projects)
#   ./install.sh /path/to/proj  # install into /path/to/proj/.claude
#
# Prefer the plugin install if your Claude Code version supports it:
#   /plugin marketplace add sofumel/claude-handoff-revive
#   /plugin install handoff-revive@handoff-revive-marketplace
#
# Use this script only if you see "/plugin isn't available in this environment"
# (older Claude Code) or you specifically want a manual install.

set -euo pipefail

# Resolve target.
if [ "${1:-}" = "--global" ]; then
  TARGET="$HOME/.claude"
elif [ -n "${1:-}" ]; then
  TARGET="$1/.claude"
else
  TARGET="./.claude"
fi

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SRC_DIR/plugins/handoff-revive"

# Verify source exists.
if [ ! -d "$PLUGIN_DIR/skills/handoff-revive" ]; then
  echo "Error: source skill not found at $PLUGIN_DIR/skills/handoff-revive" >&2
  echo "Are you running install.sh from inside the cloned repo root?" >&2
  exit 1
fi

echo "Installing handoff-revive to: $TARGET"

# Create target tree.
mkdir -p "$TARGET/skills" "$TARGET/commands" "$TARGET/hooks" "$TARGET/handoff"

# Replace existing skill / hooks dirs to avoid stale files.
if [ -d "$TARGET/skills/handoff-revive" ]; then
  echo "  (replacing existing $TARGET/skills/handoff-revive)"
  rm -rf "$TARGET/skills/handoff-revive"
fi

cp -R "$PLUGIN_DIR/skills/handoff-revive" "$TARGET/skills/"

# Dev-only test harness — not needed at runtime.
rm -rf "$TARGET/skills/handoff-revive/scripts/tests"
cp "$PLUGIN_DIR/commands/save.md"        "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/resume.md"      "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/auto.md"        "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/preview.md"     "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/list.md"        "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/restore.md"     "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/diff.md"        "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/share-to-pr.md" "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/stats.md"       "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/doctor.md"      "$TARGET/commands/"
cp "$PLUGIN_DIR/commands/switch.md"      "$TARGET/commands/"

# Copy hook setup doc so standalone users have it locally.
[ -f "$SRC_DIR/HOOK_SETUP.md" ] && cp "$SRC_DIR/HOOK_SETUP.md" "$TARGET/skills/handoff-revive/"

# Hooks (skip the plugin-only hooks.json — standalone needs settings.json snippet).
for f in \
  checkpoint-counter.sh checkpoint-counter.ps1 \
  session-start.sh session-start.ps1 \
  usage-monitor.sh usage-monitor.ps1 \
  user-prompt-submit.sh user-prompt-submit.ps1 \
  pre-compact.sh pre-compact.ps1; do
  cp "$PLUGIN_DIR/hooks/$f" "$TARGET/hooks/"
done

# Make shell hooks and scripts executable (no-op on Windows).
chmod +x "$TARGET/hooks/"*.sh                                     2>/dev/null || true
chmod +x "$TARGET/skills/handoff-revive/scripts/"*.sh             2>/dev/null || true

# Verify install.
if [ ! -f "$TARGET/skills/handoff-revive/SKILL.md" ]; then
  echo "Error: install verification failed — SKILL.md missing in target." >&2
  exit 1
fi

echo ""
echo "[OK] Installed."
echo "  Skill:           $TARGET/skills/handoff-revive"
echo "  Slash commands:  /handoff-revive:save  /handoff-revive:resume"
echo "  Hook scripts:    $TARGET/hooks/  (not yet activated)"
echo ""
echo "Next steps (optional):"
echo "  Enable Stop / SessionStart hooks by merging the snippet from"
echo "    $TARGET/skills/handoff-revive/HOOK_SETUP.md (Standalone install section)"
echo "  into $TARGET/settings.json"

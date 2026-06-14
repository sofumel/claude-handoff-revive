#!/usr/bin/env bash
# Environment diagnostics (zero LLM tokens). Prints PASS/WARN/INFO lines so
# "it doesn't work" reports come with the facts attached. Read-only; always
# exits 0 (it diagnoses, it does not judge).
#
# Usage:
#   doctor-handoff.sh

set -u

DIR=".claude/handoff"
SELF="$(cd "$(dirname "$0")" && pwd)"

pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
info() { printf 'INFO  %s\n' "$1"; }

printf '[handoff-revive] doctor\n'

# --- toolchain ---
if command -v git >/dev/null 2>&1; then
  pass "git: $(git --version 2>/dev/null | head -1)"
else
  warn "git not found — metadata, freshness and commit-aware touched_files are disabled"
fi
if command -v gh >/dev/null 2>&1; then
  pass "gh: $(gh --version 2>/dev/null | head -1)"
else
  info "gh not found — /handoff-revive:share-to-pr will not work (https://cli.github.com/)"
fi
pass "bash: ${BASH_VERSION:-unknown}"

# --- installation ---
SKILL_FILE="$SELF/../SKILL.md"
if [ -f "$SKILL_FILE" ]; then
  pass "skill files: $(cd "$SELF/.." && pwd)"
else
  warn "SKILL.md not found next to scripts — broken install?"
fi
MISSING=0
for s in validate-handoff cleanup-handoff finalize-handoff extract-recent-files \
         inject-metadata archive-current list-history restore-history diff-handoff \
         check-freshness preview-handoff sanitize-handoff share-to-pr \
         stats-handoff setup-claude-md switch-branch-handoff doctor-handoff; do
  if [ ! -f "$SELF/$s.sh" ] || [ ! -f "$SELF/$s.ps1" ]; then
    warn "script pair incomplete: $s (.sh/.ps1)"
    MISSING=1
  fi
done
[ "$MISSING" = "0" ] && pass "all script pairs present (.sh + .ps1)"

# --- hooks ---
PLUGIN_HOOKS="$SELF/../../../hooks"
if [ -f "$PLUGIN_HOOKS/hooks.json" ]; then
  pass "plugin hooks.json present (plugin install: hooks auto-activate)"
elif [ -d ".claude/hooks" ]; then
  if [ -f ".claude/settings.json" ] && grep -q 'checkpoint-counter' ".claude/settings.json" 2>/dev/null; then
    pass "standalone hooks wired in .claude/settings.json"
  else
    warn "standalone install detected but .claude/settings.json has no handoff hooks — see HOOK_SETUP.md"
  fi
else
  info "no hook installation detected here (plugin installs manage hooks via hooks.json)"
fi

# --- state ---
if [ -f "$DIR/current.md" ]; then
  if bash "$SELF/validate-handoff.sh" "$DIR/current.md" >/dev/null 2>&1; then
    pass "current.md: present and valid"
  else
    warn "current.md: present but INVALID — run validate-handoff.sh for details"
  fi
else
  info "no current handoff (nothing saved yet, or already consumed)"
fi
if [ -d "$DIR/history" ]; then
  info "history snapshots: $(ls -1 "$DIR/history"/*.md 2>/dev/null | wc -l | tr -d ' ')"
fi
if [ -f "$DIR/.stats" ]; then
  info "stats events: $(grep -c . "$DIR/.stats" 2>/dev/null || echo 0)"
fi
for marker in .session-id .session-start .last-saved .last-turn; do
  [ -f "$DIR/$marker" ] && info "marker $marker: present"
done

exit 0

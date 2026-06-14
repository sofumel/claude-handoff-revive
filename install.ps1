# Standalone installer for users who can't / don't want to use `/plugin install`.
# Copies the skill, slash commands, and hooks into a Claude Code config directory.
#
# Usage:
#   .\install.ps1                  # install into .\.claude (current project)
#   .\install.ps1 -Global          # install into $HOME\.claude (all projects)
#   .\install.ps1 -Target C:\proj  # install into C:\proj\.claude
#
# Prefer the plugin install if your Claude Code version supports it:
#   /plugin marketplace add sofumel/claude-handoff-revive
#   /plugin install handoff-revive@handoff-revive-marketplace
#
# Use this script only if you see "/plugin isn't available in this environment"
# (older Claude Code) or you specifically want a manual install.

param(
  [switch]$Global,
  [string]$Target
)

$ErrorActionPreference = "Stop"

if ($Global) {
  $dest = Join-Path $HOME ".claude"
} elseif ($Target) {
  $dest = Join-Path $Target ".claude"
} else {
  $dest = Join-Path (Get-Location).Path ".claude"
}

if ($PSScriptRoot) {
  $src = $PSScriptRoot
} else {
  $src = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$pluginDir = Join-Path $src "plugins\handoff-revive"

# Verify source exists.
$srcSkill = Join-Path $pluginDir "skills\handoff-revive"
if (-not (Test-Path $srcSkill)) {
  Write-Error "Source skill not found at $srcSkill. Are you running install.ps1 from inside the cloned repo root?"
  exit 1
}

Write-Output "Installing handoff-revive to: $dest"

# Create target tree.
$dirsToCreate = @(
  (Join-Path $dest "skills"),
  (Join-Path $dest "commands"),
  (Join-Path $dest "hooks"),
  (Join-Path $dest "handoff")
)
New-Item -ItemType Directory -Force -Path $dirsToCreate | Out-Null

# Replace existing skill dir.
$destSkill = Join-Path $dest "skills\handoff-revive"
if (Test-Path $destSkill) {
  Write-Output "  (replacing existing $destSkill)"
  Remove-Item -Recurse -Force $destSkill
}

Copy-Item -Recurse -Force $srcSkill (Join-Path $dest "skills\")

# Dev-only test harness - not needed at runtime.
$destTests = Join-Path $dest "skills\handoff-revive\scripts\tests"
if (Test-Path $destTests) {
  Remove-Item -Recurse -Force $destTests
}
Copy-Item -Force (Join-Path $pluginDir "commands\save.md")        (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\resume.md")      (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\auto.md")        (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\preview.md")     (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\list.md")        (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\restore.md")     (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\diff.md")        (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\share-to-pr.md") (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\stats.md")       (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\doctor.md")      (Join-Path $dest "commands\")
Copy-Item -Force (Join-Path $pluginDir "commands\switch.md")      (Join-Path $dest "commands\")

# Copy hook setup doc so standalone users have it locally.
$hookSetup = Join-Path $src "HOOK_SETUP.md"
if (Test-Path $hookSetup) {
  Copy-Item -Force $hookSetup (Join-Path $destSkill "HOOK_SETUP.md")
}

# Hooks (skip plugin-only hooks.json).
$hookFiles = @(
  "checkpoint-counter.sh", "checkpoint-counter.ps1",
  "session-start.sh", "session-start.ps1",
  "usage-monitor.sh", "usage-monitor.ps1",
  "user-prompt-submit.sh", "user-prompt-submit.ps1",
  "pre-compact.sh", "pre-compact.ps1"
)
foreach ($f in $hookFiles) {
  Copy-Item -Force (Join-Path $pluginDir "hooks\$f") (Join-Path $dest "hooks\")
}

# Verify install.
if (-not (Test-Path (Join-Path $destSkill "SKILL.md"))) {
  Write-Error "Install verification failed - SKILL.md missing in target."
  exit 1
}

Write-Output ""
Write-Output "Installed."
Write-Output "  Skill:           $destSkill"
Write-Output "  Slash commands:  /handoff-revive:save  /handoff-revive:resume"
Write-Output "  Hook scripts:    $dest\hooks\  (not yet activated)"
Write-Output ""
Write-Output "Next steps (optional):"
Write-Output "  Enable Stop / SessionStart hooks by merging the snippet from"
Write-Output "    $destSkill\HOOK_SETUP.md (Standalone install section)"
Write-Output "  into $dest\settings.json"

# Environment diagnostics (zero LLM tokens). Prints PASS/WARN/INFO lines.
# Read-only; always exits 0 (it diagnoses, it does not judge).

$ErrorActionPreference = "Continue"

$dir = ".claude/handoff"
if ($PSScriptRoot) { $self = $PSScriptRoot } else { $self = Split-Path -Parent $MyInvocation.MyCommand.Definition }

function Pass { param($m) Write-Output "PASS  $m" }
function Warn { param($m) Write-Output "WARN  $m" }
function Info { param($m) Write-Output "INFO  $m" }

Write-Output "[handoff-revive] doctor"

# --- toolchain ---
if (Get-Command git -ErrorAction SilentlyContinue) {
  Pass "git: $((git --version 2>$null | Select-Object -First 1))"
} else {
  Warn "git not found - metadata, freshness and commit-aware touched_files are disabled"
}
if (Get-Command gh -ErrorAction SilentlyContinue) {
  Pass "gh: $((gh --version 2>$null | Select-Object -First 1))"
} else {
  Info "gh not found - /handoff-revive:share-to-pr will not work (https://cli.github.com/)"
}
Pass "PowerShell: $($PSVersionTable.PSVersion)"

# --- installation ---
if (Test-Path (Join-Path $self "..\SKILL.md")) {
  Pass "skill files: $((Resolve-Path (Join-Path $self '..')).Path)"
} else {
  Warn "SKILL.md not found next to scripts - broken install?"
}
$missing = $false
foreach ($s in @("validate-handoff", "cleanup-handoff", "finalize-handoff", "extract-recent-files",
                 "inject-metadata", "archive-current", "list-history", "restore-history", "diff-handoff",
                 "check-freshness", "preview-handoff", "sanitize-handoff", "share-to-pr",
                 "stats-handoff", "setup-claude-md", "switch-branch-handoff", "doctor-handoff")) {
  if (-not (Test-Path (Join-Path $self "$s.sh")) -or -not (Test-Path (Join-Path $self "$s.ps1"))) {
    Warn "script pair incomplete: $s (.sh/.ps1)"
    $missing = $true
  }
}
if (-not $missing) { Pass "all script pairs present (.sh + .ps1)" }

# --- hooks ---
$pluginHooks = Join-Path $self "..\..\..\hooks"
if (Test-Path (Join-Path $pluginHooks "hooks.json")) {
  Pass "plugin hooks.json present (plugin install: hooks auto-activate)"
} elseif (Test-Path ".claude/hooks") {
  if ((Test-Path ".claude/settings.json") -and ((Get-Content ".claude/settings.json" -Raw -ErrorAction SilentlyContinue) -match 'checkpoint-counter')) {
    Pass "standalone hooks wired in .claude/settings.json"
  } else {
    Warn "standalone install detected but .claude/settings.json has no handoff hooks - see HOOK_SETUP.md"
  }
} else {
  Info "no hook installation detected here (plugin installs manage hooks via hooks.json)"
}

# --- state ---
if (Test-Path "$dir/current.md") {
  & (Join-Path $self "validate-handoff.ps1") -File "$dir/current.md" *> $null
  if ($LASTEXITCODE -eq 0) {
    Pass "current.md: present and valid"
  } else {
    Warn "current.md: present but INVALID - run validate-handoff.ps1 for details"
  }
} else {
  Info "no current handoff (nothing saved yet, or already consumed)"
}
if (Test-Path "$dir/history") {
  Info "history snapshots: $(@(Get-ChildItem "$dir/history" -Filter '*.md' -ErrorAction SilentlyContinue).Count)"
}
if (Test-Path "$dir/.stats") {
  Info "stats events: $(@(Get-Content "$dir/.stats" -ErrorAction SilentlyContinue).Count)"
}
foreach ($marker in @(".session-id", ".session-start", ".last-saved", ".last-turn")) {
  if (Test-Path "$dir/$marker") { Info "marker ${marker}: present" }
}

exit 0

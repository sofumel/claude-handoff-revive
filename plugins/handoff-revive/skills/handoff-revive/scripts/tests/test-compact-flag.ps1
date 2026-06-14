# PreCompact gate + relay (feature ①, gate redesign), PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$pluginDir = (Resolve-Path (Join-Path $skillDir "..\..")).Path
$preCompact = Join-Path $pluginDir "hooks\pre-compact.ps1"
$ups = Join-Path $pluginDir "hooks\user-prompt-submit.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

# Hooks read process stdin / use process-cwd path APIs: spawn child shells
# (which inherit the test's working directory).
$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
function Invoke-Hook {
  param($script, $json, [hashtable]$envVars = @{})
  foreach ($k in $envVars.Keys) { Set-Item "env:$k" $envVars[$k] }
  try { return ($json | & $psExe -NoProfile -ExecutionPolicy Bypass -File $script) -join "`n" }
  finally { foreach ($k in $envVars.Keys) { Remove-Item "env:$k" -ErrorAction SilentlyContinue } }
}

function Reset-Marker {
  Remove-Item ".claude\handoff\.compact-flag", ".claude\handoff\.last-turn", `
              ".claude\handoff\.last-saved", ".claude\handoff\.usage-flag" -ErrorAction SilentlyContinue
}
function Set-Unsaved { "2000000" | Set-Content ".claude\handoff\.last-turn" -NoNewline; "1000000" | Set-Content ".claude\handoff\.last-saved" -NoNewline }
function Set-Saved   { "1000000" | Set-Content ".claude\handoff\.last-turn" -NoNewline; "1000000" | Set-Content ".claude\handoff\.last-saved" -NoNewline }

try {
  Set-Location $work
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null

  # --- fresh: allowed, marker written ---
  Reset-Marker
  $out = Invoke-Hook $preCompact '{"trigger":"manual"}'
  if ($out) { Write-Output "fresh manual should not block: $out"; exit 1 }
  if (-not (Test-Path ".claude\handoff\.compact-flag")) { Write-Output "allow should write marker"; exit 1 }
  Write-Output "fresh manual: allowed"

  # --- manual + unsaved: BLOCKED, no marker ---
  Reset-Marker; Set-Unsaved
  $out = Invoke-Hook $preCompact '{"trigger":"manual"}'
  if ($out -notmatch '"decision":"block"') { Write-Output "unsaved manual must block: $out"; exit 1 }
  if ($out -notmatch 'handoff-revive:save') { Write-Output "block reason should mention save: $out"; exit 1 }
  if (Test-Path ".claude\handoff\.compact-flag") { Write-Output "blocked compact must not write marker"; exit 1 }
  Write-Output "unsaved manual: blocked"

  # --- manual + saved: allowed ---
  Reset-Marker; Set-Saved
  $out = Invoke-Hook $preCompact '{"trigger":"manual"}'
  if ($out) { Write-Output "saved manual should not block: $out"; exit 1 }
  if (-not (Test-Path ".claude\handoff\.compact-flag")) { Write-Output "allow should write marker"; exit 1 }
  Write-Output "saved manual: allowed"

  # --- auto + unsaved: never blocked ---
  Reset-Marker; Set-Unsaved
  $out = Invoke-Hook $preCompact '{"trigger":"auto"}'
  if ($out) { Write-Output "auto compaction must never block: $out"; exit 1 }
  if (-not (Test-Path ".claude\handoff\.compact-flag")) { Write-Output "auto allow should write marker"; exit 1 }
  Write-Output "auto + unsaved: allowed (never blocks)"

  # --- gate off + unsaved: allowed ---
  Reset-Marker; Set-Unsaved
  $out = Invoke-Hook $preCompact '{"trigger":"manual"}' @{ HANDOFF_COMPACT_GATE = "off" }
  if ($out) { Write-Output "gate off should not block: $out"; exit 1 }
  Write-Output "gate off: allowed"

  # --- relay: allowed marker surfaced once ---
  Reset-Marker
  Invoke-Hook $preCompact '{"trigger":"manual"}' | Out-Null
  $out = Invoke-Hook $ups '{}'
  if ($out -notmatch 'context compaction') { Write-Output "compact notice missing: $out"; exit 1 }
  if (Test-Path ".claude\handoff\.compact-flag") { Write-Output "marker should be consumed"; exit 1 }
  $out = Invoke-Hook $ups '{}'
  if ($out) { Write-Output "second prompt should be silent: $out"; exit 1 }
  Write-Output "relay: one-shot"

  # --- usage + compact combined relay ---
  Reset-Marker
  "AUTO_SAVE:92" | Set-Content ".claude\handoff\.usage-flag" -NoNewline
  Invoke-Hook $preCompact '{"trigger":"auto"}' | Out-Null
  $out = Invoke-Hook $ups '{}'
  if ($out -notmatch '92 percent') { Write-Output "usage part missing: $out"; exit 1 }
  if ($out -notmatch 'context compaction') { Write-Output "compact part missing: $out"; exit 1 }
  Write-Output "combined relay: OK"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

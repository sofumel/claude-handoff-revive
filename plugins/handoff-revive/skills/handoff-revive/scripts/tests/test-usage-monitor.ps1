# usage-monitor band logic, PowerShell ports (previously CI-inline only).

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$pluginDir = (Resolve-Path (Join-Path $skillDir "..\..")).Path
$mon = Join-Path $pluginDir "hooks\usage-monitor.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

# The hook reads process stdin: spawn a child shell per call.
$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
function Feed {
  param($sid, $pct)
  "{`"session_id`":`"$sid`",`"rate_limits`":{`"five_hour`":{`"used_percentage`":$pct}}}" |
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $mon | Out-Null
}

try {
  Set-Location $work
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null

  Feed s1 50
  if (Test-Path ".claude\handoff\.usage-flag") { Write-Output "no flag expected at 50%"; exit 1 }
  Write-Output "50%: silent"

  Feed s1 92
  if ((Get-Content ".claude\handoff\.usage-flag" -Raw).Trim() -ne "AUTO_SAVE:92") { Write-Output "AUTO_SAVE flag wrong"; exit 1 }
  if ((Get-Content ".claude\handoff\.last-warned" -Raw).Trim() -ne "90") { Write-Output "band not recorded"; exit 1 }
  Write-Output "92%: AUTO_SAVE + band 90"

  Remove-Item ".claude\handoff\.usage-flag" -Force
  Feed s1 93
  if (Test-Path ".claude\handoff\.usage-flag") { Write-Output "93% must not re-fire within band 90"; exit 1 }
  Write-Output "93%: no re-fire"

  Feed s1 96
  if ((Get-Content ".claude\handoff\.usage-flag" -Raw).Trim() -ne "URGENT:96") { Write-Output "URGENT flag wrong"; exit 1 }
  if ((Get-Content ".claude\handoff\.last-warned" -Raw).Trim() -ne "95") { Write-Output "band not upgraded"; exit 1 }
  Write-Output "96%: URGENT + band 95"

  Feed s1 30
  if (Test-Path ".claude\handoff\.last-warned") { Write-Output "reset must clear band"; exit 1 }
  if (Test-Path ".claude\handoff\.usage-flag") { Write-Output "reset must clear flag"; exit 1 }
  Write-Output "30%: window reset"

  New-Item -ItemType Directory -Path ".claude\handoff\sessions" -Force | Out-Null
  New-Item -ItemType File -Path ".claude\handoff\sessions\s2.disabled" -Force | Out-Null
  Feed s2 92
  if (Test-Path ".claude\handoff\.usage-flag") { Write-Output "disabled session must not flag"; exit 1 }
  Write-Output "session disable: respected"

  $env:HANDOFF_AUTO_SAVE_PERCENT = "disabled"
  $env:HANDOFF_URGENT_PERCENT = "disabled"
  Feed s3 98
  $env:HANDOFF_AUTO_SAVE_PERCENT = $null
  $env:HANDOFF_URGENT_PERCENT = $null
  if (Test-Path ".claude\handoff\.usage-flag") { Write-Output "env disable must not flag"; exit 1 }
  Write-Output "env disable: respected"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

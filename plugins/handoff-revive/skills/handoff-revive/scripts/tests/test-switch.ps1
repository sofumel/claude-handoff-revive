# Per-branch handoff switch, PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$switch = Join-Path $scriptsDir "switch-branch-handoff.ps1"
$inject = Join-Path $scriptsDir "inject-metadata.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $work "repo") -Force | Out-Null
$origLoc = Get-Location

function Set-Handoff {
  param($marker)
  Copy-Item $example ".claude\handoff\current.md" -Force
  (Get-Content ".claude\handoff\current.md" -Raw) -replace 'timing-safe な比較', $marker |
    Set-Content ".claude\handoff\current.md" -NoNewline
  & $inject -File ".claude\handoff\current.md"
}

try {
  Set-Location (Join-Path $work "repo")
  git init -q -b main
  git config user.name T
  git config user.email t@x.com
  git commit -q --allow-empty -m init
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null

  Set-Handoff "MAIN HANDOFF"

  # --- same branch: no-op ---
  $out = (& $switch) -join "`n"
  if ($out -notmatch 'nothing to switch') { Write-Output "expected no-op: $out"; exit 1 }
  Write-Output "same branch: no-op"

  # --- switch to feature/x: main parked, clean slate ---
  git checkout -q -b feature/x
  $out = (& $switch) -join "`n"
  if ($out -notmatch 'parked the "main" handoff') { Write-Output "park message missing: $out"; exit 1 }
  if ($out -notmatch 'clean slate') { Write-Output "clean-slate message missing: $out"; exit 1 }
  if (-not (Test-Path ".claude\handoff\branches\main.md")) { Write-Output "parked file missing"; exit 1 }
  if (Test-Path ".claude\handoff\current.md") { Write-Output "current should be gone (clean slate)"; exit 1 }
  Write-Output "park: main stashed, clean slate"

  # --- feature handoff, switch back: round-trip intact ---
  Set-Handoff "FEATURE HANDOFF"
  git checkout -q main
  $out = (& $switch) -join "`n"
  if ($out -notmatch 'restored the handoff parked for branch "main"') { Write-Output "restore message missing: $out"; exit 1 }
  if ((Get-Content ".claude\handoff\current.md" -Raw) -notmatch 'MAIN HANDOFF') { Write-Output "main handoff not restored"; exit 1 }
  if ((Get-Content ".claude\handoff\branches\feature_x.md" -Raw) -notmatch 'FEATURE HANDOFF') { Write-Output "feature handoff not parked (slug)"; exit 1 }
  Write-Output "round-trip: both handoffs intact (slash slugged)"

  # --- no metadata: clean error ---
  Copy-Item $example ".claude\handoff\current.md" -Force
  & $switch *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "missing metadata must error"; exit 1 }
  Write-Output "no metadata: rejected"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

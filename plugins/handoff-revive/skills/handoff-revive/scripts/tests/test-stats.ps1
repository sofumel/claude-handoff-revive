# Stats (record/show), PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$stats = Join-Path $scriptsDir "stats-handoff.ps1"

$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
$finalize = Join-Path $scriptsDir "finalize-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

try {
  Set-Location $work
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null

  # --- empty state ---
  $out = (& $stats -Cmd show) -join "`n"
  if ($out -notmatch 'no stats yet') { Write-Output "expected empty-state message: $out"; exit 1 }
  Write-Output "empty: friendly message"

  # --- finalize records a save (child shell: scripts resolve via process cwd) ---
  Copy-Item $example ".claude\handoff\current.md"
  & $psExe -NoProfile -ExecutionPolicy Bypass -File $finalize -File ".claude\handoff\current.md" *> $null
  if (-not (Select-String -Path ".claude\handoff\.stats" -Pattern '^\d+ save \d+$' -Quiet)) {
    Write-Output "save event missing: $(Get-Content '.claude\handoff\.stats' -Raw)"; exit 1
  }
  Write-Output "finalize: save recorded"

  # --- resume recorded; show aggregates (skips malformed lines) ---
  & $stats -Cmd record -Kind resume | Out-Null
  Add-Content ".claude\handoff\.stats" "garbage line"
  $out = (& $stats -Cmd show) -join "`n"
  if ($out -notmatch 'saves:   1') { Write-Output "save count wrong: $out"; exit 1 }
  if ($out -notmatch 'resumes: 1') { Write-Output "resume count wrong: $out"; exit 1 }
  if ($out -notmatch 'ASSUMPTION') { Write-Output "assumption label missing: $out"; exit 1 }
  Write-Output "show: counts + honest estimate"

  # --- bad subcommand errors ---
  & $stats -Cmd record -Kind bogus *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "bogus kind should fail"; exit 1 }
  Write-Output "validation: bad kind rejected"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

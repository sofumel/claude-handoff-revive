# Doctor, PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$doctor = Join-Path $scriptsDir "doctor-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

try {
  Set-Location $work

  # --- healthy checkout, no handoff yet ---
  $out = (& $doctor) -join "`n"
  if ($out -notmatch 'PASS  git:') { Write-Output "git check missing: $out"; exit 1 }
  if ($out -notmatch 'all script pairs present') { Write-Output "pair check failed: $out"; exit 1 }
  if ($out -notmatch 'no current handoff') { Write-Output "expected no-handoff INFO: $out"; exit 1 }
  Write-Output "healthy: PASS lines present"

  # --- invalid handoff -> WARN, still exit 0 ---
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null
  "garbage" | Set-Content ".claude\handoff\current.md"
  $out = (& $doctor) -join "`n"
  if ($out -notmatch 'WARN  current\.md: present but INVALID') { Write-Output "expected INVALID warn: $out"; exit 1 }
  Write-Output "invalid handoff: WARN emitted, exit 0"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

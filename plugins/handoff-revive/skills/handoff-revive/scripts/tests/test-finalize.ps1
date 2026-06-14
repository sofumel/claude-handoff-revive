# finalize-handoff.ps1: exit 0 on valid input, exit 1 on invalid input.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$finalize = Join-Path $scriptsDir "finalize-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

try {
  # --- valid file: exit 0 ---
  $fz = Join-Path $work "fz.md"
  Copy-Item $example $fz
  & $finalize -File $fz *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "finalize failed on valid input"; exit 1 }
  Write-Output "valid: finalized"

  # --- invalid file: exit 1 ---
  $bad = Join-Path $work "bad.md"
  "garbage" | Set-Content $bad
  & $finalize -File $bad *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "invalid input should have exited 1"; exit 1 }
  Write-Output "invalid: rejected as expected"

  exit 0
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

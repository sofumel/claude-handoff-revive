# validate-handoff.ps1: accepts the shipped example, rejects broken input.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$validate = Join-Path $scriptsDir "validate-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

try {
  # --- valid example passes ---
  & $validate -File $example *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "valid example was rejected"; exit 1 }
  Write-Output "valid example: accepted"

  # --- missing required section is rejected ---
  $c = Join-Path $work "c.md"
  Get-Content $example | Where-Object { $_ -notmatch '^## decisions' } | Set-Content $c
  & $validate -File $c *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "missing-section case should have been rejected"; exit 1 }
  Write-Output "missing section: rejected as expected"

  # --- garbage is rejected ---
  $bad = Join-Path $work "bad.md"
  "garbage" | Set-Content $bad
  & $validate -File $bad *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "garbage should have been rejected"; exit 1 }
  Write-Output "garbage: rejected as expected"

  exit 0
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

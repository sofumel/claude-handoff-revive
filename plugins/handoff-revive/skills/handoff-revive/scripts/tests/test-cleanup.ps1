# cleanup-handoff.ps1: runs clean, is idempotent, and the result still validates.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$cleanup = Join-Path $scriptsDir "cleanup-handoff.ps1"
$validate = Join-Path $scriptsDir "validate-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

try {
  # --- runs without error ---
  $i = Join-Path $work "i.md"
  Copy-Item $example $i
  & $cleanup -File $i *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "cleanup failed on example"; exit 1 }
  Write-Output "cleanup: OK"

  # --- idempotent: second run does not change the file ---
  $h1 = (Get-FileHash $i -Algorithm SHA256).Hash
  & $cleanup -File $i *> $null
  $h2 = (Get-FileHash $i -Algorithm SHA256).Hash
  if ($h1 -ne $h2) { Write-Output "not idempotent"; exit 1 }
  Write-Output "idempotent: OK"

  # --- cleaned file still validates ---
  & $validate -File $i *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "cleaned file no longer validates"; exit 1 }
  Write-Output "post-cleanup validate: OK"

  exit 0
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

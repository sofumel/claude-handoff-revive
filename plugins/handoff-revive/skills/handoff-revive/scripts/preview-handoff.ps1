# Read-only RESUME dry-run (zero LLM tokens): shows exactly what a fresh
# session would read, plus validation result, token estimate and freshness.
# Never modifies the handoff file.

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $dir = $PSScriptRoot } else { $dir = Split-Path -Parent $MyInvocation.MyCommand.Definition }

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: file not found: $File")
  exit 1
}

$size = (Get-Item $File).Length
$tokens = [int]($size / 4)

Write-Output "[handoff-revive] preview: $File"
Write-Output "  size: $size bytes (~$tokens tokens - rough estimate, model-dependent)"

& (Join-Path $dir "validate-handoff.ps1") -File $File *> $null
if ($LASTEXITCODE -eq 0) {
  Write-Output "  validation: OK"
} else {
  Write-Output "  validation: INVALID - run validate-handoff.ps1 for the issue list"
}

$fresh = & (Join-Path $dir "check-freshness.ps1") -File $File 2>$null
if ($fresh) {
  $fresh | ForEach-Object { Write-Output "  $_" }
} else {
  Write-Output "  freshness: OK (current commit/branch, or no metadata to check)"
}

Write-Output "---- content (what a fresh session will read) ----"
Get-Content $File
exit 0

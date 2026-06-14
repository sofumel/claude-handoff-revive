# lessons_learned is an OPTIONAL schema section (PowerShell ports):
#   - example with the section validates
#   - removing the section entirely still validates
#   - an empty lessons_learned section is stripped by cleanup and still validates

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$validate = Join-Path $scriptsDir "validate-handoff.ps1"
$cleanup = Join-Path $scriptsDir "cleanup-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

function Remove-LessonsSection {
  param($lines)
  $out = @(); $skip = $false
  foreach ($l in $lines) {
    if ($l -match '^## lessons_learned$') { $skip = $true; continue }
    if ($l -match '^## ') { $skip = $false }
    if (-not $skip) { $out += $l }
  }
  return $out
}

try {
  # --- example ships with lessons_learned and validates ---
  $raw = Get-Content $example
  if (-not ($raw -match '^## lessons_learned$')) { Write-Output "example.md is missing lessons_learned"; exit 1 }
  & $validate -File $example *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "example with lessons_learned was rejected"; exit 1 }
  Write-Output "with lessons_learned: accepted"

  # --- removing the whole section still validates (optional) ---
  $without = Join-Path $work "without.md"
  (Remove-LessonsSection $raw) | Set-Content $without
  & $validate -File $without *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "handoff without lessons_learned was rejected"; exit 1 }
  Write-Output "without lessons_learned: accepted"

  # --- empty section is stripped by cleanup, result still validates ---
  $empty = Join-Path $work "empty.md"
  ((Remove-LessonsSection $raw) + @("", "## lessons_learned")) | Set-Content $empty
  & $cleanup -File $empty *> $null
  if ((Get-Content $empty) -match '^## lessons_learned$') {
    Write-Output "empty lessons_learned should have been stripped by cleanup"
    exit 1
  }
  & $validate -File $empty *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "post-strip file no longer validates"; exit 1 }
  Write-Output "empty section: stripped and still valid"

  exit 0
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

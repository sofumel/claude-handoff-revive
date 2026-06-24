# Print a tiny RESUME receipt before edits begin.
# The receipt confirms the load boundary without dumping handoff contents:
# it reports metadata, section names, counts and freshness status only.
#
# Usage:
#   .\resume-receipt.ps1
#   .\resume-receipt.ps1 -File path\to\handoff.md

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: file not found: $File")
  exit 1
}

if ($PSScriptRoot) { $dir = $PSScriptRoot } else { $dir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$content = Get-Content $File

function Get-FrontmatterValue([string]$Key) {
  foreach ($line in $content) {
    if ($line -match "^$([Regex]::Escape($Key)):\s*(.*?)\s*$") {
      return ($matches[1] -replace '^"(.*)"$', '$1')
    }
  }
  return ""
}

$sections = @()
foreach ($line in $content) {
  if ($line -match '^##\s+([A-Za-z0-9_ -]+)\s*$') { $sections += $matches[1].Trim() }
}

$touchedCount = 0
$inTouched = $false
$nextActionPresent = $false
$inNextAction = $false
foreach ($line in $content) {
  if ($line -match '^##\s+touched_files\s*$') { $inTouched = $true; $inNextAction = $false; continue }
  if ($line -match '^##\s+next_action\s*$') { $inNextAction = $true; $inTouched = $false; continue }
  if ($line -match '^##\s+') { $inTouched = $false; $inNextAction = $false; continue }
  if ($inTouched -and $line -match '^-\s+') { $touchedCount++ }
  if ($inNextAction -and $line.Trim().Length -gt 0) { $nextActionPresent = $true }
}

$savedAt = Get-FrontmatterValue "saved_at"
$branch = Get-FrontmatterValue "branch"
$baseCommit = Get-FrontmatterValue "base_commit"
$currentBranch = "unknown"
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -eq 0) {
  $currentBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
  if (-not $currentBranch) { $currentBranch = "unknown" }
}

$check = Join-Path $dir "check-freshness.ps1"
$freshnessOutput = (& $check -File $File 2>$null) | Where-Object { $_ }
$freshnessWarnings = @($freshnessOutput | Where-Object { $_ -match '^\[handoff-revive\] freshness:' }).Count

Write-Output "[handoff-revive] resume receipt"
Write-Output "  handoff: $File"
Write-Output "  saved_at: $(if ($savedAt) { $savedAt } else { 'unknown' })"
Write-Output "  branch: saved=$(if ($branch) { $branch } else { 'unknown' }) current=$currentBranch"
if ($baseCommit) {
  Write-Output "  base_commit: $($baseCommit.Substring(0, [Math]::Min(12, $baseCommit.Length)))"
} else {
  Write-Output "  base_commit: unknown"
}
Write-Output "  loaded: current.md only"
Write-Output "  not_loaded: prior transcript; history snapshots; other handoff files"
Write-Output "  sections_present: $($sections.Count) ($(if ($sections.Count) { $sections -join ', ' } else { 'none' }))"
Write-Output "  touched_files_count: $touchedCount"
Write-Output "  next_action_present: $($nextActionPresent.ToString().ToLowerInvariant())"
if ($freshnessWarnings -gt 0) {
  Write-Output "  freshness: warnings=$freshnessWarnings (see check-freshness output)"
} else {
  Write-Output "  freshness: ok"
}
Write-Output "  privacy: raw_prior_transcript_included=false; history_snapshots_included=false; handoff_body_echoed=false"

exit 0

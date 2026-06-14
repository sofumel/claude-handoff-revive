# Restore a snapshot as the current handoff (zero LLM tokens).
# The existing current.md is archived first, so a restore is never destructive.
#
# Usage:
#   restore-history.ps1 -Timestamp 20260610T031500Z [-File path\to\handoff.md]

param(
  [Parameter(Mandatory = $false)][string]$Timestamp = "",
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Stop"

if (-not $Timestamp) {
  [Console]::Error.WriteLine("ERROR: usage: restore-history.ps1 -Timestamp <ts> - run list-history.ps1 to see snapshots.")
  exit 1
}
$Timestamp = $Timestamp -replace '\.md$', ''

$histDir = Join-Path (Split-Path -Parent $File) "history"
$src = Join-Path $histDir "$Timestamp.md"

if (-not (Test-Path $src)) {
  $matches_ = @(Get-ChildItem -Path $histDir -Filter "$Timestamp*.md" -ErrorAction SilentlyContinue)
  if ($matches_.Count -eq 0) {
    [Console]::Error.WriteLine("ERROR: no snapshot matches `"$Timestamp`". Run list-history.ps1 to see what exists.")
    exit 1
  } elseif ($matches_.Count -gt 1) {
    [Console]::Error.WriteLine("ERROR: `"$Timestamp`" is ambiguous ($($matches_.Count) matches): $($matches_.Name -join ', ')")
    exit 1
  }
  $src = $matches_[0].FullName
}

if ($PSScriptRoot) { $dirSelf = $PSScriptRoot } else { $dirSelf = Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Never destroy the present: archive current.md before overwriting it.
if (Test-Path $File) {
  try { & (Join-Path $dirSelf "archive-current.ps1") -File $File *> $null } catch {}
}

Copy-Item $src $File -Force
Write-Output "[handoff-revive] restored $(Split-Path -Leaf $src) -> $File"
Write-Output "[handoff-revive] the previous current.md was archived to history first."
exit 0

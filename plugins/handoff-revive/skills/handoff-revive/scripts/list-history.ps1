# List handoff snapshots, newest first (zero LLM tokens).

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Continue"

$histDir = Join-Path (Split-Path -Parent $File) "history"

$files = @()
if (Test-Path $histDir) {
  $files = @(Get-ChildItem -Path $histDir -Filter "*.md" | Sort-Object Name -Descending)
}
if ($files.Count -eq 0) {
  Write-Output "[handoff-revive] no snapshots yet. Each save will archive one automatically."
  exit 0
}

Write-Output "[handoff-revive] $($files.Count) snapshot(s), newest first:"
foreach ($f in $files) {
  $goal = "?"
  $hit = $false
  foreach ($l in (Get-Content $f.FullName)) {
    if ($hit -and $l.Trim()) { $goal = $l.Trim(); break }
    if ($l -match '^## goal\s*$') { $hit = $true }
  }
  if ($goal.Length -gt 80) { $goal = $goal.Substring(0, 80) }
  Write-Output ("  {0}  {1,6} bytes  goal: {2}" -f $f.Name, $f.Length, $goal)
}
exit 0

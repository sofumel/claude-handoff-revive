# Stop hook: increment turn counter, nudge user every N turns.
# Does NOT auto-invoke the skill (would burn tokens silently).

$ErrorActionPreference = "Stop"

$dir = ".claude/handoff"
$counter = "$dir/.turn"

$thresholdRaw = $env:HANDOFF_CHECKPOINT_EVERY
$threshold = 15
if (-not [string]::IsNullOrWhiteSpace($thresholdRaw) -and $thresholdRaw -match '^\d+$') {
  $parsed = [int]$thresholdRaw
  if ($parsed -gt 0) { $threshold = $parsed }
}

if (-not (Test-Path $dir)) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$count = 0
if (Test-Path $counter) {
  $raw = (Get-Content $counter -Raw)
  if ($raw) {
    $clean = $raw.Trim().TrimStart([char]0xFEFF)
    if ($clean -match '^\d+$') { $count = [int]$clean }
  }
}

$count = $count + 1

# Write without BOM so next read parses cleanly.
# Use [IO.Path]::GetFullPath (does not require the dir to currently exist) instead of
# Resolve-Path (throws on transient deletion).
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$absPath   = [IO.Path]::GetFullPath((Join-Path $dir ".turn"))
[System.IO.File]::WriteAllText($absPath, "$count", $utf8NoBom)

if ($count % $threshold -eq 0) {
  [Console]::Error.WriteLine("[handoff-revive] Turn $count - checkpoint due. Run /handoff to save.")
}

exit 0

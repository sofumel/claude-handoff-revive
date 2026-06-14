# Stop hook: record per-turn markers, and OPTIONALLY nudge the user to save.
#
# The turn-count nudge is OFF by default — it only fires when the user opts in
# by setting HANDOFF_CHECKPOINT_EVERY to a positive number (e.g. =15 nudges
# every 15 turns). Without it, this hook is silent.
#
# Always: increments .turn and records .last-turn (epoch). .last-turn is
# required by the unsaved-exit detection and the PreCompact gate, so this hook
# stays installed even when the nudge is off. Never auto-invokes the skill.

$ErrorActionPreference = "Stop"

$dir = ".claude/handoff"
$counter = "$dir/.turn"

# Nudge is opt-in: enabled only when HANDOFF_CHECKPOINT_EVERY is a positive int.
$nudgeEvery = 0
$nudge = $false
if (-not [string]::IsNullOrWhiteSpace($env:HANDOFF_CHECKPOINT_EVERY) -and $env:HANDOFF_CHECKPOINT_EVERY -match '^\d+$') {
  $parsed = [int]$env:HANDOFF_CHECKPOINT_EVERY
  if ($parsed -gt 0) { $nudgeEvery = $parsed; $nudge = $true }
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

# Record last-activity timestamp (epoch seconds). Used by session-start to
# detect "previous session ended without saving" and by the PreCompact gate -
# compared against the .last-saved marker written by finalize-handoff.
$epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$ltPath = [IO.Path]::GetFullPath((Join-Path $dir ".last-turn"))
[System.IO.File]::WriteAllText($ltPath, "$epoch", $utf8NoBom)

if ($nudge -and ($count % $nudgeEvery -eq 0)) {
  [Console]::Error.WriteLine("[handoff-revive] Turn $count - checkpoint due. Run /handoff-revive:save to save.")
}

exit 0

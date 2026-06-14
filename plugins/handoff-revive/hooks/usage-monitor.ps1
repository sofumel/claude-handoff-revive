# PostToolUse hook: monitor 5-hour usage rate.
#
# Reads rate_limits.five_hour.used_percentage from stdin JSON. When it crosses
# configurable thresholds (default 90% / 95%), writes a flag file that the
# UserPromptSubmit hook reads to instruct Claude to auto-save a handoff.
#
# State files written under .claude/handoff/:
#   .usage-flag      one-shot directive ("AUTO_SAVE:92" or "URGENT:96")
#   .last-warned     last threshold crossed (90 or 95)
#
# Environment variables:
#   HANDOFF_AUTO_SAVE_PERCENT   default 90, "disabled" to skip
#   HANDOFF_URGENT_PERCENT      default 95, "disabled" to skip

$ErrorActionPreference = "SilentlyContinue"

$dir = ".claude/handoff"
$sessionsDir = "$dir/sessions"
$flagFile = "$dir/.usage-flag"
$lastWarnedFile = "$dir/.last-warned"

# --- Configuration ---
$autoSaveStr = $env:HANDOFF_AUTO_SAVE_PERCENT
if ([string]::IsNullOrWhiteSpace($autoSaveStr)) { $autoSaveStr = "90" }
$urgentStr = $env:HANDOFF_URGENT_PERCENT
if ([string]::IsNullOrWhiteSpace($urgentStr)) { $urgentStr = "95" }

# Both disabled? Nothing to do.
if ($autoSaveStr -eq "disabled" -and $urgentStr -eq "disabled") { exit 0 }

$autoSave = if ($autoSaveStr -match '^\d+$') { [int]$autoSaveStr } else { -1 }
$urgent = if ($urgentStr -match '^\d+$') { [int]$urgentStr } else { -1 }

# --- Read input ---
$inputData = [Console]::In.ReadToEnd()
$usage = 0
$sessionId = $null

if ($inputData) {
  try {
    $parsed = $inputData | ConvertFrom-Json
    if ($parsed.rate_limits -and $parsed.rate_limits.five_hour) {
      $usage = [int]$parsed.rate_limits.five_hour.used_percentage
    }
    $sessionId = $parsed.session_id
  } catch {}
}

New-Item -ItemType Directory -Force -Path $dir, $sessionsDir | Out-Null

# --- Per-session disable check ---
if ($sessionId -and (Test-Path "$sessionsDir/$sessionId.disabled")) {
  exit 0
}

# --- Read last warned threshold ---
$lastWarned = 0
if (Test-Path $lastWarnedFile) {
  $raw = (Get-Content $lastWarnedFile -Raw -ErrorAction SilentlyContinue)
  if ($raw) {
    $clean = $raw.Trim().TrimStart([char]0xFEFF)
    if ($clean -match '^\d+$') { $lastWarned = [int]$clean }
  }
}

# --- Reset on window reset ---
if ($usage -lt 50 -and $lastWarned -gt 0) {
  Remove-Item $lastWarnedFile, $flagFile -Force -ErrorAction SilentlyContinue
  exit 0
}

# --- Determine new flag ---
$newFlag = $null
$newThreshold = 0

# URGENT takes precedence
if ($urgent -ge 0 -and $usage -ge $urgent -and $lastWarned -lt $urgent) {
  $newFlag = "URGENT:$usage"
  $newThreshold = $urgent
}

# AUTO_SAVE if no URGENT
if (-not $newFlag -and $autoSave -ge 0 -and $usage -ge $autoSave -and $lastWarned -lt $autoSave) {
  $newFlag = "AUTO_SAVE:$usage"
  $newThreshold = $autoSave
}

# --- Write flag and update last_warned ---
# Order: write last_warned FIRST, then flag. Reason: if user-prompt-submit
# fires concurrently and consumes the flag, .last-warned is already updated,
# so a subsequent PostToolUse won't re-fire the same threshold.
if ($newFlag) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [IO.File]::WriteAllText([IO.Path]::GetFullPath($lastWarnedFile), "$newThreshold", $utf8NoBom)
  [IO.File]::WriteAllText([IO.Path]::GetFullPath($flagFile), $newFlag, $utf8NoBom)
}

exit 0

# UserPromptSubmit hook: read .usage-flag (set by usage-monitor.ps1) and inject
# `additionalContext` so Claude proactively auto-saves a handoff before responding.
#
# Flag is one-shot: removed after read.

$ErrorActionPreference = "SilentlyContinue"

$dir = ".claude/handoff"
$flagFile = "$dir/.usage-flag"

if (-not (Test-Path $flagFile)) { exit 0 }

# Atomically claim the flag (rename so usage-monitor can't write a new one
# in the same name and have it lost). Move-Item is atomic within the same
# volume on Windows.
$claimed = "$flagFile.claimed.$PID"
try {
  Move-Item -Path $flagFile -Destination $claimed -Force -ErrorAction Stop
} catch {
  exit 0
}

# Read & delete the claimed copy.
$flag = (Get-Content $claimed -Raw -ErrorAction SilentlyContinue)
Remove-Item $claimed -Force -ErrorAction SilentlyContinue

if (-not $flag) { exit 0 }
$flag = $flag.Trim().TrimStart([char]0xFEFF)
if (-not $flag) { exit 0 }

# Parse flag: "AUTO_SAVE:92" or "URGENT:96"
$parts = $flag -split ':', 2
$type = $parts[0]
$percent = if ($parts.Length -ge 2) { $parts[1] } else { "?" }

$msg = $null
$pct = [string]$percent
switch ($type) {
  "URGENT" {
    $msg = "CRITICAL: 5-hour usage at " + $pct + " percent. IMMEDIATELY auto-save a handoff before answering the user. Run the SAVE flow (extract-recent-files then write handoff to .claude/handoff/current.md then finalize-handoff). Do NOT ask the user. After save completes, briefly notify them in their language (see Mode 1c URGENT row in SKILL.md for per-language phrasing) then handle their original request. If finalize-handoff fails after 2 retries, warn the user and continue anyway."
  }
  "AUTO_SAVE" {
    $msg = "5-hour usage at " + $pct + " percent. Auto-save a handoff before answering the user. Run the SAVE flow (extract-recent-files then write handoff then finalize-handoff). Do NOT ask the user. After save, briefly notify them in their language (see Mode 1c AUTO_SAVE row in SKILL.md for per-language phrasing) then handle their request."
  }
  default {
    exit 0
  }
}

if (-not $msg) { exit 0 }

$payload = @{
  hookSpecificOutput = @{
    hookEventName     = "UserPromptSubmit"
    additionalContext = $msg
  }
} | ConvertTo-Json -Compress -Depth 5

[Console]::Out.Write($payload)
exit 0

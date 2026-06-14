# PreCompact hook: GATE a MANUAL /compact when there is unsaved work, so the
# pre-compact context is never lost (saving after /compact only captures the
# already-compressed summary).
#
# Hooks cannot invoke Claude (no inference turn at compaction time), so the
# hook cannot write a handoff itself. What it CAN do is BLOCK the compaction
# with a reason. If there is unsaved work, block the manual /compact and tell
# the user to run /handoff-revive:save first.
#
# Scope and safety:
#   - MANUAL /compact only. AUTO compaction is NEVER blocked (could wedge the
#     session with no way to free context).
#   - "Unsaved work" reuses .last-turn (Stop hook) vs .last-saved (finalize).
#     Block only on positive evidence; missing markers = allow.
#   - HANDOFF_COMPACT_GATE=off disables the gate.
#
# On allow, a .compact-flag marker is written; UserPromptSubmit relays it on
# the next prompt so Claude won't overwrite the pre-compact handoff.

$ErrorActionPreference = "SilentlyContinue"

$dir = ".claude/handoff"
if (-not (Test-Path $dir)) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$inputData = [Console]::In.ReadToEnd()
$trigger = "unknown"
if ($inputData -match '"trigger"\s*:\s*"manual"') { $trigger = "manual" }
elseif ($inputData -match '"trigger"\s*:\s*"auto"') { $trigger = "auto" }

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-MarkerAndAllow {
  $epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $flagPath = [IO.Path]::GetFullPath((Join-Path $dir ".compact-flag"))
  [System.IO.File]::WriteAllText($flagPath, "${trigger}:${epoch}", $utf8NoBom)
  exit 0
}

# Gate disabled, or auto-compaction → never block.
$gate = if ($env:HANDOFF_COMPACT_GATE) { $env:HANDOFF_COMPACT_GATE } else { "on" }
if ($gate -eq "off" -or $trigger -eq "auto") {
  Write-MarkerAndAllow
}

# --- Unsaved-work detection (positive evidence only) ---
$tol = 120
if ($env:HANDOFF_UNSAVED_TOLERANCE_SECONDS -match '^\d+$') { $tol = [int]$env:HANDOFF_UNSAVED_TOLERANCE_SECONDS }
$lastTurn = ""
$lastSaved = ""
if (Test-Path "$dir/.last-turn")  { $lastTurn  = (Get-Content "$dir/.last-turn" -Raw).Trim() }
if (Test-Path "$dir/.last-saved") { $lastSaved = (Get-Content "$dir/.last-saved" -Raw).Trim() }

$unsaved = $false
if ($lastTurn -match '^\d+$') {
  if (-not ($lastSaved -match '^\d+$') -or ([long]$lastTurn -gt ([long]$lastSaved + $tol))) {
    $unsaved = $true
  }
}

if (-not $unsaved) {
  Write-MarkerAndAllow
}

# --- Block: emit a JSON decision (parsed at exit 0 per the hook contract). ---
$reason = "Unsaved work detected. Run /handoff-revive:save first so the pre-compact state is preserved, then run /compact again. Set HANDOFF_COMPACT_GATE=off to disable this gate."
$payload = @{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress
[Console]::Out.Write($payload)
exit 0

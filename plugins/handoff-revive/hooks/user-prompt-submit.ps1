# UserPromptSubmit hook: relay one-shot flags into `additionalContext`.
#   .usage-flag   (usage-monitor.ps1)  -> auto-save directive
#   .compact-flag (pre-compact hook)   -> compaction-happened notice
#
# Flags are one-shot: removed after read.

$ErrorActionPreference = "SilentlyContinue"

$dir = ".claude/handoff"
$flagFile = "$dir/.usage-flag"
$compactFlag = "$dir/.compact-flag"
$msg = ""

# --- usage flag ---
if (Test-Path $flagFile) {
  # Atomically claim the flag (rename so usage-monitor can't write a new one
  # in the same name and have it lost). Move-Item is atomic within the same
  # volume on Windows.
  $claimed = "$flagFile.claimed.$PID"
  $haveFlag = $false
  try {
    Move-Item -Path $flagFile -Destination $claimed -Force -ErrorAction Stop
    $haveFlag = $true
  } catch {}

  if ($haveFlag) {
    $flag = (Get-Content $claimed -Raw -ErrorAction SilentlyContinue)
    Remove-Item $claimed -Force -ErrorAction SilentlyContinue
    if ($flag) { $flag = $flag.Trim().TrimStart([char]0xFEFF) }

    if ($flag) {
      # Parse flag: "AUTO_SAVE:92" or "URGENT:96"
      $parts = $flag -split ':', 2
      $type = $parts[0]
      $percent = if ($parts.Length -ge 2) { $parts[1] } else { "?" }
      $pct = [string]$percent
      switch ($type) {
        "URGENT" {
          $msg = "CRITICAL: 5-hour usage at " + $pct + " percent. IMMEDIATELY auto-save a handoff before answering the user. Run the SAVE flow (extract-recent-files then write handoff to .claude/handoff/current.md then finalize-handoff). Do NOT ask the user. After save completes, briefly notify them in their language (see Mode 1c URGENT row in SKILL.md for per-language phrasing) then handle their original request. If finalize-handoff fails after 2 retries, warn the user and continue anyway."
        }
        "AUTO_SAVE" {
          $msg = "5-hour usage at " + $pct + " percent. Auto-save a handoff before answering the user. Run the SAVE flow (extract-recent-files then write handoff then finalize-handoff). Do NOT ask the user. After save, briefly notify them in their language (see Mode 1c AUTO_SAVE row in SKILL.md for per-language phrasing) then handle their request."
        }
      }
    }
  }
}

# --- compact flag (one-shot) ---
if (Test-Path $compactFlag) {
  $cclaimed = "$compactFlag.claimed.$PID"
  $haveCompact = $false
  try {
    Move-Item -Path $compactFlag -Destination $cclaimed -Force -ErrorAction Stop
    $haveCompact = $true
  } catch {}

  if ($haveCompact) {
    Remove-Item $cclaimed -Force -ErrorAction SilentlyContinue
    $cmsg = "NOTICE: a context compaction (/compact) occurred before this prompt. Pre-compact details now exist only in compressed form. If .claude/handoff/current.md was saved BEFORE the compaction, treat it as the authoritative pre-compact record - do NOT overwrite it from post-compact memory without the user's confirmation (suggest /handoff-revive:preview to review it first). Saving new post-compact work is fine."
    if ($msg) { $msg = $msg + "`n`n" + $cmsg } else { $msg = $cmsg }
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

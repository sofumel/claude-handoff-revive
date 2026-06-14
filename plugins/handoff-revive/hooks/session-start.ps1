# SessionStart hook:
#   1. Captures session_id to .claude/handoff/.session-id.
#   2. Cleans up orphaned per-session toggle files (>30 days old).
#   3. Clears stale .usage-flag from previous sessions.
#   4. Surfaces existing handoff if recent.

$ErrorActionPreference = "SilentlyContinue"

$dir = ".claude/handoff"
$file = "$dir/current.md"
$sessionsDir = "$dir/sessions"
$sessionIdFile = "$dir/.session-id"

New-Item -ItemType Directory -Force -Path $dir, $sessionsDir | Out-Null

# --- Read JSON input from stdin ---
$inputData = [Console]::In.ReadToEnd()
$sessionId = $null
if ($inputData) {
  try {
    $parsed = $inputData | ConvertFrom-Json
    $sessionId = $parsed.session_id
  } catch {}
}

# --- 1. Persist session_id ---
if ($sessionId) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [IO.File]::WriteAllText([IO.Path]::GetFullPath($sessionIdFile), $sessionId, $utf8NoBom)
}

# --- 1.5 Record session start time (epoch) ---
# Used by extract-recent-files to include files committed DURING this session
# in touched_files (git status alone misses already-committed work).
$utf8NoBomSs = New-Object System.Text.UTF8Encoding $false
$epochSs = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
[IO.File]::WriteAllText([IO.Path]::GetFullPath((Join-Path $dir ".session-start")), "$epochSs", $utf8NoBomSs)

# --- 2. Clean up orphaned per-session toggle files (>30 days old) ---
$cutoff = (Get-Date).AddDays(-30)
Get-ChildItem -Path $sessionsDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -lt $cutoff } |
  Remove-Item -Force -ErrorAction SilentlyContinue

# --- 2.5 Clean up old handoff snapshots ---
$retention = 30
if ($env:HANDOFF_HISTORY_RETENTION_DAYS -match '^\d+$') { $retention = [int]$env:HANDOFF_HISTORY_RETENTION_DAYS }
if ($retention -gt 0 -and (Test-Path "$dir/history")) {
  $histCutoff = (Get-Date).AddDays(-$retention)
  Get-ChildItem -Path "$dir/history" -Filter "*.md" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $histCutoff } |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

# --- 3. Clear stale state from previous sessions ---
# .turn        — Stop hook turn counter (reset per session so nudges fire
#                at turn 15 of THIS session)
# .usage-flag  — one-shot directive left over if previous session crashed
# .last-warned — threshold band (reset per session)
Remove-Item "$dir/.turn", "$dir/.usage-flag", "$dir/.last-warned" -ErrorAction SilentlyContinue

# --- 3.5 Detect unsaved exit of the previous session ---
# .last-turn (Stop hook, every turn) vs .last-saved (finalize-handoff, every
# successful save). Last activity newer than last save (beyond tolerance) =
# the previous session ended without saving. One-shot: .last-turn is consumed
# here. These two markers intentionally survive the cleanup above.
$unsavedNote = ""
$tol = 120
if ($env:HANDOFF_UNSAVED_TOLERANCE_SECONDS -match '^\d+$') { $tol = [int]$env:HANDOFF_UNSAVED_TOLERANCE_SECONDS }
$lastTurn = ""
$lastSaved = ""
if (Test-Path "$dir/.last-turn") { $lastTurn = (Get-Content "$dir/.last-turn" -Raw).Trim() }
if (Test-Path "$dir/.last-saved") { $lastSaved = (Get-Content "$dir/.last-saved" -Raw).Trim() }
if ($lastTurn -match '^\d+$') {
  if (-not ($lastSaved -match '^\d+$') -or ([long]$lastTurn -gt ([long]$lastSaved + $tol))) {
    $unsavedNote = "NOTE: the previous session ended WITHOUT saving a handoff (there was activity after the last save). If a handoff file exists it may be stale. If the user wants to continue prior work, offer to update/rebuild the handoff after confirming the current state with them."
  }
  Remove-Item "$dir/.last-turn" -ErrorAction SilentlyContinue
}

# --- 4. Surface existing handoff if recent ---
# The handoff never expires; this window only controls whether we proactively
# remind the user at session start. Configurable via HANDOFF_SURFACE_DAYS
# (default 7). Older handoffs are still usable via /handoff-revive:resume.
$surfaceDays = 7
if ($env:HANDOFF_SURFACE_DAYS -match '^\d+$') { $surfaceDays = [int]$env:HANDOFF_SURFACE_DAYS }
$surface = $true
if (-not (Test-Path $file)) {
  $surface = $false
} elseif (((Get-Date) - (Get-Item $file).LastWriteTime).TotalDays -gt $surfaceDays) {
  $surface = $false
}

$context = ""
if ($surface) {
$context = @"
A handoff checkpoint exists at ``.claude/handoff/current.md`` (saved recently).

If the user wants to continue prior work, READ THAT FILE — do NOT suggest ``claude --resume`` or ``claude -c`` (those replay your entire prior conversation, typically tens of thousands of tokens; the handoff file costs ~1-3k).

The user can resume by running the slash command ``/handoff-revive:resume``. If they ask to "continue" / "resume" in natural language, briefly remind them to run ``/handoff-revive:resume`` (do NOT auto-invoke the skill on natural-language phrases — only on the slash command).
"@

# --- 5. Branch mismatch warning ---
# If the handoff carries `branch:` metadata and it differs from the current
# branch, it likely belongs to different work. Inform Claude (informational
# only; legacy handoffs without metadata, non-git dirs and detached HEAD skip).
$savedBranch = ""
foreach ($l in (Get-Content $file)) {
  if ($l -match '^branch:\s*"?([^"]*?)"?\s*$') { $savedBranch = $matches[1]; break }
}
if ($savedBranch) {
  git rev-parse --is-inside-work-tree *> $null
  if ($LASTEXITCODE -eq 0) {
    $currentBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
    if ($currentBranch -and $currentBranch -ne "HEAD" -and $savedBranch -ne $currentBranch) {
      $context += "`n`nNOTE: the handoff was saved on branch `"$savedBranch`" but the current branch is `"$currentBranch`". It may belong to different work - mention this if the user resumes, suggest /handoff-revive:switch to park it and restore this branch's own handoff, and confirm with them before overwriting it on the next save."
    }
  }
}
}  # end surface

# Append the unsaved-exit note (emitted even when no handoff is surfaced).
if ($unsavedNote) {
  if ($context) { $context += "`n`n$unsavedNote" } else { $context = $unsavedNote }
}

if (-not $context) { exit 0 }

$payload = @{
  hookSpecificOutput = @{
    hookEventName     = "SessionStart"
    additionalContext = $context
  }
} | ConvertTo-Json -Compress -Depth 5

[Console]::Out.Write($payload)
exit 0

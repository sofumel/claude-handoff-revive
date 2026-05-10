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

# --- 2. Clean up orphaned per-session toggle files (>30 days old) ---
$cutoff = (Get-Date).AddDays(-30)
Get-ChildItem -Path $sessionsDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -lt $cutoff } |
  Remove-Item -Force -ErrorAction SilentlyContinue

# --- 3. Clear stale state from previous sessions ---
# .turn        — Stop hook turn counter (reset per session so nudges fire
#                at turn 15 of THIS session)
# .usage-flag  — one-shot directive left over if previous session crashed
# .last-warned — threshold band (reset per session)
Remove-Item "$dir/.turn", "$dir/.usage-flag", "$dir/.last-warned" -ErrorAction SilentlyContinue

# --- 4. Surface existing handoff if recent ---
if (-not (Test-Path $file)) { exit 0 }

$age = (Get-Date) - (Get-Item $file).LastWriteTime
if ($age.TotalDays -gt 7) { exit 0 }

$context = @"
A handoff checkpoint exists at ``.claude/handoff/current.md`` (saved within the last 7 days).

If the user wants to continue prior work, READ THAT FILE — do NOT suggest ``claude --resume`` or ``claude -c`` (those replay the entire transcript and cost 30k-200k tokens; the handoff file costs ~1-3k).

The user can resume by running the slash command ``/resume-from-handoff``. If they ask to "continue" / "resume" in natural language, briefly remind them to run ``/resume-from-handoff`` (do NOT auto-invoke the skill on natural-language phrases — only on the slash command).
"@

$payload = @{
  hookSpecificOutput = @{
    hookEventName     = "SessionStart"
    additionalContext = $context
  }
} | ConvertTo-Json -Compress -Depth 5

[Console]::Out.Write($payload)
exit 0

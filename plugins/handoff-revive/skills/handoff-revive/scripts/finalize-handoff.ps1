# finalize-handoff: validate + cleanup + savings report in a single call.
# Replaces the three-tool-call sequence (validate, cleanup, savings) used during SAVE.
#
# Exit codes:
#   0  - handoff is valid and finalized; savings report on stderr.
#   1  - validation failed; error list on stderr (Claude should fix and re-call).

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Stop"

if ($PSScriptRoot) {
  $dir = $PSScriptRoot
} else {
  $dir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

# Phase 1: validate. Invoke the script directly (in-process) — do NOT spawn a
# separate `powershell.exe`. Spawning would:
#   * fail on PowerShell 7-only systems (no powershell.exe on Linux/macOS)
#   * be ~1s slower per call (process startup)
#   * be killed by $PSNativeCommandUseErrorActionPreference under PS 7.4+
#     before our $LASTEXITCODE check could run.
$validateScript = Join-Path $dir "validate-handoff.ps1"
& $validateScript -File $File | Out-Null
if ($LASTEXITCODE -ne 0) {
  exit 1
}

# Phase 2: cleanup. Stderr messages pass through to user.
$cleanupScript = Join-Path $dir "cleanup-handoff.ps1"
& $cleanupScript -File $File
if ($LASTEXITCODE -ne 0) {
  [Console]::Error.WriteLine("[finalize-handoff] cleanup failed; aborting.")
  exit 1
}

# Phase 2.5: inject git metadata into frontmatter (best-effort; never blocks the save).
$injectScript = Join-Path $dir "inject-metadata.ps1"
try { & $injectScript -File $File } catch {}

# Record last-save timestamp next to the handoff (epoch seconds). Paired with
# the Stop hook's .last-turn marker to detect unsaved session exits.
try {
  $epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  $lsPath = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($File))) ".last-saved"))
  [System.IO.File]::WriteAllText($lsPath, "$epoch", $utf8NoBom)
} catch {}

# Phase 2.7: snapshot this save into history/ (best-effort; never blocks).
try { & (Join-Path $dir "archive-current.ps1") -File $File *> $null } catch {}

# Phase 2.8: count the save for /handoff-revive:stats (best-effort).
try { & (Join-Path $dir "stats-handoff.ps1") -Cmd record -Kind save -File $File *> $null } catch {}

# Phase 3: savings report.
$size = (Get-Item $File).Length
$tokens = [int]($size / 4)

[Console]::Error.WriteLine("[handoff-revive] OK Saved $File (~$tokens tokens).")
[Console]::Error.WriteLine("[handoff-revive] Estimated savings on next resume: tens of thousands of tokens (vs --resume replaying full prior context).")

exit 0

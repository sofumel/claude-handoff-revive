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

# Phase 3: savings report.
$size = (Get-Item $File).Length
$tokens = [int]($size / 4)

[Console]::Error.WriteLine("[handoff-revive] OK Saved $File (~$tokens tokens).")
[Console]::Error.WriteLine("[handoff-revive] Estimated savings on next resume: ~30,000-200,000 tokens (vs --resume replaying full transcript).")

exit 0

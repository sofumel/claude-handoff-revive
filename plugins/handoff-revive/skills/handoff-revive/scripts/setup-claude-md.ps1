# OPT-IN: append a guidance comment to CLAUDE.md so future sessions keep
# volatile work state in handoffs instead of CLAUDE.md.
#
# Never called automatically - running this script IS the user's consent.
# Idempotent: if the marker is already present, nothing is written.
# Existing content is never modified, only appended to; the file is created
# if it does not exist.

param(
  [string]$File = "CLAUDE.md"
)

$ErrorActionPreference = "Stop"

$marker = 'claude-handoff-revive:'
$block = '<!-- claude-handoff-revive: For volatile work state (current task, next_action, WIP), use /handoff-revive:save instead of writing it here. CLAUDE.md is for durable project knowledge: conventions, architecture, commands. -->'

if ((Test-Path $File) -and ((Get-Content $File -Raw) -match [regex]::Escape($marker))) {
  Write-Output "[handoff-revive] guidance comment already present in $File - nothing to do."
  exit 0
}

if (Test-Path $File) {
  Add-Content -Path $File -Value "`n$block"
} else {
  # Resolve against the PowerShell location, NOT [IO.Path]::GetFullPath —
  # the latter uses the PROCESS cwd, which Set-Location does not update,
  # and would create the file in the wrong directory.
  $full = if ([System.IO.Path]::IsPathRooted($File)) { $File } else { Join-Path (Get-Location).Path $File }
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($full, "$block`n", $utf8NoBom)
}

Write-Output "[handoff-revive] guidance comment appended to $File"
exit 0

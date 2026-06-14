# CLAUDE.md guidance (feature ⑥), PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$setup = Join-Path $scriptsDir "setup-claude-md.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

try {
  Set-Location $work

  # --- appends to an existing file without touching its content ---
  "# My project`n`nExisting durable knowledge." | Set-Content CLAUDE.md
  & $setup | Out-Null
  $c = Get-Content CLAUDE.md -Raw
  if ($c -notmatch '# My project') { Write-Output "existing content damaged"; exit 1 }
  if ($c -notmatch 'claude-handoff-revive:') { Write-Output "comment not appended"; exit 1 }
  Write-Output "append: existing content preserved"

  # --- idempotent: second run changes nothing ---
  $h1 = (Get-FileHash CLAUDE.md -Algorithm SHA256).Hash
  $out = (& $setup) -join "`n"
  $h2 = (Get-FileHash CLAUDE.md -Algorithm SHA256).Hash
  if ($h1 -ne $h2) { Write-Output "second run modified the file"; exit 1 }
  if ($out -notmatch 'already present') { Write-Output "expected already-present notice: $out"; exit 1 }
  Write-Output "idempotent: OK"

  # --- creates the file when missing ---
  Remove-Item CLAUDE.md
  & $setup | Out-Null
  if (-not (Test-Path CLAUDE.md)) { Write-Output "file not created"; exit 1 }
  if ((Get-Content CLAUDE.md -Raw) -notmatch 'claude-handoff-revive:') { Write-Output "comment missing in created file"; exit 1 }
  Write-Output "create: OK"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

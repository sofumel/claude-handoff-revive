# Unsaved-exit detection (feature ⑨), PowerShell ports:
#   - finalize writes .last-saved; Stop hook writes .last-turn
#   - activity after last save (beyond tolerance) -> SessionStart NOTE, once
#   - saved recently -> silent
#   - works even when no current.md exists (standalone note)

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$pluginDir = (Resolve-Path (Join-Path $skillDir "..\..")).Path
$sessionStart = Join-Path $pluginDir "hooks\session-start.ps1"
$stopHook = Join-Path $pluginDir "hooks\checkpoint-counter.ps1"
$finalize = Join-Path $scriptsDir "finalize-handoff.ps1"
$example = Join-Path $skillDir "templates\example.md"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

# All hooks/scripts are spawned as child shells, exactly like the real
# invocations: session-start reads process stdin, and the scripts resolve
# relative paths via [IO.Path]::GetFullPath which uses the PROCESS cwd —
# an in-process call after Set-Location would write outside the temp dir.
$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
function Invoke-SessionStart {
  param($json)
  return ($json | & $psExe -NoProfile -ExecutionPolicy Bypass -File $sessionStart) -join "`n"
}
function Invoke-Child {
  param($script, [string[]]$scriptArgs = @())
  & $psExe -NoProfile -ExecutionPolicy Bypass -File $script @scriptArgs *> $null
}

try {
  Set-Location $work
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null
  Copy-Item $example ".claude\handoff\current.md"

  # --- markers are written by the producing scripts ---
  Invoke-Child $stopHook
  if (-not (Test-Path ".claude\handoff\.last-turn")) { Write-Output ".last-turn not written by Stop hook"; exit 1 }
  Invoke-Child $finalize @("-File", ".claude\handoff\current.md")
  if (-not (Test-Path ".claude\handoff\.last-saved")) { Write-Output ".last-saved not written by finalize"; exit 1 }
  Write-Output "markers: written"

  # --- saved after activity (within tolerance): silent ---
  $out = Invoke-SessionStart '{"session_id":"s1"}'
  if ($out -match 'WITHOUT saving') { Write-Output "unexpected unsaved note after save"; exit 1 }
  Write-Output "saved exit: silent"

  # --- activity after save beyond tolerance: NOTE fires once ---
  "1000000" | Set-Content ".claude\handoff\.last-saved" -NoNewline
  "2000000" | Set-Content ".claude\handoff\.last-turn" -NoNewline
  $out = Invoke-SessionStart '{"session_id":"s2"}'
  if ($out -notmatch 'WITHOUT saving') { Write-Output "expected unsaved note, got: $out"; exit 1 }
  $out = Invoke-SessionStart '{"session_id":"s3"}'
  if ($out -match 'WITHOUT saving') { Write-Output "note should fire only once"; exit 1 }
  Write-Output "unsaved exit: noted once"

  # --- within tolerance: silent ---
  "1000000" | Set-Content ".claude\handoff\.last-saved" -NoNewline
  "1000060" | Set-Content ".claude\handoff\.last-turn" -NoNewline
  $out = Invoke-SessionStart '{"session_id":"s4"}'
  if ($out -match 'WITHOUT saving') { Write-Output "tolerance not respected"; exit 1 }
  Write-Output "tolerance: silent"

  # --- no current.md at all: standalone note still emitted ---
  Remove-Item ".claude\handoff\current.md", ".claude\handoff\.last-saved" -ErrorAction SilentlyContinue
  "2000000" | Set-Content ".claude\handoff\.last-turn" -NoNewline
  $out = Invoke-SessionStart '{"session_id":"s5"}'
  if ($out -notmatch 'WITHOUT saving') { Write-Output "expected standalone note, got: $out"; exit 1 }
  if ($out -match 'handoff checkpoint exists') { Write-Output "should not surface missing handoff"; exit 1 }
  Write-Output "no handoff: standalone note"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

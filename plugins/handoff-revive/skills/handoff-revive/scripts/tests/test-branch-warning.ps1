# session-start.ps1 branch mismatch warning:
#   - handoff saved on another branch -> additionalContext contains the NOTE
#   - same branch -> no NOTE (but normal handoff context still present)
#   - legacy handoff without branch metadata -> no NOTE

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$pluginDir = (Resolve-Path (Join-Path $skillDir "..\..")).Path
$hook = Join-Path $pluginDir "hooks\session-start.ps1"
$example = Join-Path $skillDir "templates\example.md"
$inject = Join-Path $scriptsDir "inject-metadata.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

# The hook reads process stdin via [Console]::In.ReadToEnd(); an in-process
# `& $hook` would block on the console. Spawn a child PowerShell so the piped
# string becomes its stdin (same as the real hook invocation).
$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
function Invoke-Hook {
  param($json)
  return ($json | & $psExe -NoProfile -ExecutionPolicy Bypass -File $hook) -join "`n"
}

try {
  $repo = Join-Path $work "repo"
  New-Item -ItemType Directory -Path $repo | Out-Null
  Set-Location $repo
  git init -q -b main
  git config user.name "Test"
  git config user.email "t@example.com"
  git commit -q --allow-empty -m init
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null
  Copy-Item $example ".claude\handoff\current.md"
  & $inject -File ".claude\handoff\current.md"   # stamps branch: "main"

  # --- same branch: handoff surfaced, no branch NOTE ---
  $out = Invoke-Hook '{"session_id":"t1"}'
  if ($out -notmatch 'handoff checkpoint exists') { Write-Output "expected handoff context, got: $out"; exit 1 }
  if ($out -match 'saved on branch') { Write-Output "unexpected branch NOTE on same branch"; exit 1 }
  Write-Output "same branch: no NOTE"

  # --- different branch: NOTE present with both branch names ---
  git checkout -q -b feature/y
  $out = Invoke-Hook '{"session_id":"t2"}'
  if ($out -notmatch 'saved on branch') { Write-Output "expected NOTE with saved branch, got: $out"; exit 1 }
  if ($out -notmatch 'feature/y') { Write-Output "expected current branch in NOTE, got: $out"; exit 1 }
  Write-Output "different branch: NOTE emitted"

  # --- legacy handoff without metadata: no NOTE ---
  Copy-Item $example ".claude\handoff\current.md" -Force
  $out = Invoke-Hook '{"session_id":"t3"}'
  if ($out -match 'saved on branch') { Write-Output "unexpected NOTE for legacy handoff"; exit 1 }
  Write-Output "legacy handoff: no NOTE"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

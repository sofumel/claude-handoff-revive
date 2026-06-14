# Section-wise diff (feature ⑤), PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$finalize = Join-Path $scriptsDir "finalize-handoff.ps1"
$diff = Join-Path $scriptsDir "diff-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
function Invoke-Child {
  param($script, [string[]]$scriptArgs = @())
  & $psExe -NoProfile -ExecutionPolicy Bypass -File $script @scriptArgs *> $null
}

try {
  Set-Location $work
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null

  # save #1
  Copy-Item $example ".claude\handoff\current.md"
  Invoke-Child $finalize @("-File", ".claude\handoff\current.md")

  # save #2: add a done item, change next_action (keep file:line — required by validator)
  $raw = Get-Content $example -Raw
  $raw = $raw -replace '(?m)^## wip', "- NEWLY DONE ITEM`n## wip"
  $raw = $raw -replace '(?m)^Edit src/auth/login\.ts:42 —.*', 'Edit src/auth/password-reset.ts:31 — apply the same safeCompare replacement.'
  $raw | Set-Content ".claude\handoff\current.md" -NoNewline
  Invoke-Child $finalize @("-File", ".claude\handoff\current.md")

  # --- default: compares against previous save ---
  $out = (& $diff -File ".claude\handoff\current.md") -join "`n"
  if ($out -notmatch '## done') { Write-Output "expected done section in diff: $out"; exit 1 }
  if ($out -notmatch '\+ - NEWLY DONE ITEM') { Write-Output "expected added done item: $out"; exit 1 }
  if ($out -notmatch '## next_action') { Write-Output "expected next_action section: $out"; exit 1 }
  if ($out -notmatch 'section\(s\) changed') { Write-Output "expected change count: $out"; exit 1 }
  Write-Output "default diff: previous save compared"

  # --- explicit timestamp: oldest snapshot ---
  $oldest = Get-ChildItem ".claude\handoff\history" -Filter "*.md" | Sort-Object Name | Select-Object -First 1
  $out = (& $diff -Timestamp $oldest.BaseName -File ".claude\handoff\current.md") -join "`n"
  if ($out -notmatch '\+ - NEWLY DONE ITEM') { Write-Output "explicit timestamp diff failed: $out"; exit 1 }
  Write-Output "explicit timestamp: OK"

  # --- unknown timestamp errors ---
  & $psExe -NoProfile -ExecutionPolicy Bypass -File $diff -Timestamp "19990101T000000Z" -File ".claude\handoff\current.md" *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "unknown timestamp should fail"; exit 1 }
  Write-Output "unknown timestamp: rejected"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

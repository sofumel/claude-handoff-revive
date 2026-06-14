# History archive (feature ③), PowerShell ports:
#   - each finalize snapshots into history/ (collision-safe)
#   - list-history shows snapshots newest first
#   - restore brings back an old snapshot and archives current first
#   - session-start prunes snapshots older than retention

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$pluginDir = (Resolve-Path (Join-Path $skillDir "..\..")).Path
$example = Join-Path $skillDir "templates\example.md"
$finalize = Join-Path $scriptsDir "finalize-handoff.ps1"
$list = Join-Path $scriptsDir "list-history.ps1"
$restore = Join-Path $scriptsDir "restore-history.ps1"
$sessionStart = Join-Path $pluginDir "hooks\session-start.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
function Invoke-Child {
  param($script, [string[]]$scriptArgs = @())
  & $psExe -NoProfile -ExecutionPolicy Bypass -File $script @scriptArgs *> $null
}
function Invoke-SessionStart {
  param($json)
  return ($json | & $psExe -NoProfile -ExecutionPolicy Bypass -File $sessionStart) -join "`n"
}

try {
  Set-Location $work
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null
  $hist = ".claude\handoff\history"

  # --- save #1 creates a snapshot ---
  Copy-Item $example ".claude\handoff\current.md"
  Invoke-Child $finalize @("-File", ".claude\handoff\current.md")
  $n = @(Get-ChildItem $hist -Filter "*.md").Count
  if ($n -ne 1) { Write-Output "expected 1 snapshot, got $n"; exit 1 }

  # --- save #2 (same second is fine: timestamp bumps +1s) ---
  (Get-Content $example -Raw) -replace 'timing-safe な比較', 'SECOND SAVE MARKER' | Set-Content ".claude\handoff\current.md" -NoNewline
  Invoke-Child $finalize @("-File", ".claude\handoff\current.md")
  $n = @(Get-ChildItem $hist -Filter "*.md").Count
  if ($n -ne 2) { Write-Output "expected 2 snapshots, got $n"; exit 1 }
  Write-Output "archive per save: OK ($n snapshots)"

  # --- list shows both ---
  $out = (& $list -File ".claude\handoff\current.md") -join "`n"
  if ($out -notmatch '2 snapshot\(s\)') { Write-Output "list count wrong: $out"; exit 1 }
  if ($out -notmatch 'goal:') { Write-Output "list missing goal column: $out"; exit 1 }
  Write-Output "list: OK"

  # --- restore the OLDEST snapshot (original goal text) ---
  $oldest = Get-ChildItem $hist -Filter "*.md" | Sort-Object Name | Select-Object -First 1
  Invoke-Child $restore @("-Timestamp", $oldest.BaseName, "-File", ".claude\handoff\current.md")
  if (-not (Select-String -Path ".claude\handoff\current.md" -Pattern 'timing-safe' -Quiet)) {
    Write-Output "restore did not bring back old content"; exit 1
  }
  $n = @(Get-ChildItem $hist -Filter "*.md").Count
  if ($n -ne 3) { Write-Output "expected 3 snapshots after restore, got $n"; exit 1 }
  Write-Output "restore: OK (current archived first)"

  # --- unknown timestamp errors cleanly ---
  & $psExe -NoProfile -ExecutionPolicy Bypass -File $restore -Timestamp "19990101T000000Z" -File ".claude\handoff\current.md" *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "unknown timestamp should fail"; exit 1 }
  Write-Output "unknown timestamp: rejected"

  # --- same-second collision: timestamp bumps, never overwrites, uniform names ---
  $archive = Join-Path $scriptsDir "archive-current.ps1"
  $t0 = (Get-Date).ToUniversalTime()
  for ($i = 0; $i -le 5; $i++) {
    $ts = $t0.AddSeconds($i).ToString("yyyyMMddTHHmmssZ")
    New-Item -ItemType File -Path (Join-Path $hist "$ts.md") -Force | Out-Null
  }
  $before = @(Get-ChildItem $hist -Filter "*.md").Count
  & $archive -File ".claude\handoff\current.md" *> $null
  $after = @(Get-ChildItem $hist -Filter "*.md").Count
  if ($after -ne ($before + 1)) { Write-Output "collision archive should add exactly 1 file ($before -> $after)"; exit 1 }
  $bad = @(Get-ChildItem $hist | Where-Object { $_.Name -notmatch '^\d{8}T\d{6}Z\.md$' })
  if ($bad.Count -gt 0) { Write-Output "non-uniform snapshot names found: $($bad.Name -join ', ')"; exit 1 }
  Write-Output "collision: +1s bump, uniform names"

  # --- retention: old snapshot pruned by session-start ---
  $old = Join-Path $hist "20000101T000000Z.md"
  Copy-Item $example $old
  (Get-Item $old).LastWriteTime = Get-Date "2000-01-01"
  Invoke-SessionStart '{"session_id":"h1"}' | Out-Null
  if (Test-Path $old) { Write-Output "old snapshot should have been pruned"; exit 1 }
  Write-Output "retention: pruned"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

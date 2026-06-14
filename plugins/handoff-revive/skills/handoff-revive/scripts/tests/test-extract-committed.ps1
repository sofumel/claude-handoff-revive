# Commit-aware touched_files (feature ④), PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$extract = Join-Path $scriptsDir "extract-recent-files.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $work "repo") -Force | Out-Null
$origLoc = Get-Location

try {
  Set-Location (Join-Path $work "repo")
  git init -q -b main
  git config user.name "Test"
  git config user.email "t@example.com"
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null
  $past = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 3600
  "$past" | Set-Content ".claude\handoff\.session-start" -NoNewline

  # --- committed-only ---
  "a" | Set-Content committed.ts
  git add committed.ts
  git commit -q -m c1
  $out = (& $extract) -join "`n"
  if ($out -notmatch '- committed\.ts -- committed this session') { Write-Output "committed file missing: $out"; exit 1 }
  Write-Output "committed-only: listed"

  # --- both + dedupe ---
  "b" | Set-Content uncommitted.ts
  Add-Content committed.ts "mod"
  $out = (& $extract) -join "`n"
  if ($out -notmatch '- uncommitted\.ts -- untracked / new') { Write-Output "uncommitted missing: $out"; exit 1 }
  if ($out -notmatch '- committed\.ts -- modified') { Write-Output "modified reason missing: $out"; exit 1 }
  $n = @(($out -split "`n") | Where-Object { $_ -match '- committed\.ts' }).Count
  if ($n -ne 1) { Write-Output "committed.ts duplicated ($n): $out"; exit 1 }
  Write-Output "both: merged + deduped"

  # --- upstream exclusion ---
  git add -A
  git commit -q -m c2
  git init -q --bare (Join-Path $work "origin.git")
  git remote add origin (Join-Path $work "origin.git")
  git push -q -u origin main 2>$null
  "c" | Set-Content local-only.ts
  git add local-only.ts
  git commit -q -m c3
  $out = (& $extract) -join "`n"
  if ($out -notmatch '- local-only\.ts -- committed this session') { Write-Output "local-ahead commit missing: $out"; exit 1 }
  if ($out -match '- committed\.ts') { Write-Output "pushed file should be excluded: $out"; exit 1 }
  Write-Output "upstream: pushed commits excluded"

  # --- no .session-start: legacy behavior ---
  Remove-Item ".claude\handoff\.session-start"
  "d" | Set-Content newfile.ts
  $out = (& $extract) -join "`n"
  if ($out -notmatch '- newfile\.ts -- untracked / new') { Write-Output "untracked missing: $out"; exit 1 }
  if ($out -match 'committed this session') { Write-Output "no committed scan expected without marker: $out"; exit 1 }
  Write-Output "no marker: legacy behavior"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

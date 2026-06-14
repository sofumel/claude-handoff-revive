# check-freshness.ps1: silent when fresh / legacy / non-git; warns on commits
# since save and on branch mismatch; "cannot verify" on unknown base_commit.
# Always exits 0 (informational, never blocks resume).

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$check = Join-Path $scriptsDir "check-freshness.ps1"
$inject = Join-Path $scriptsDir "inject-metadata.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

try {
  $repo = Join-Path $work "repo"
  New-Item -ItemType Directory -Path $repo | Out-Null
  Set-Location $repo
  git init -q -b main
  git config user.name "Test"
  git config user.email "t@example.com"
  git commit -q --allow-empty -m c1
  Copy-Item $example h.md
  & $inject -File h.md

  # --- fresh: silent ---
  $out = & $check -File h.md
  if ($out) { Write-Output "expected silence when fresh, got: $out"; exit 1 }
  Write-Output "fresh: silent"

  # --- commits added since save: warns with count ---
  git commit -q --allow-empty -m c2
  git commit -q --allow-empty -m c3
  $out = (& $check -File h.md) -join "`n"
  if ($out -notmatch '2 commit\(s\) ago') { Write-Output "expected 2-commit warning, got: $out"; exit 1 }
  Write-Output "stale commits: warned"

  # --- branch mismatch: warns ---
  git checkout -q -b feature/x
  $out = (& $check -File h.md) -join "`n"
  if ($out -notmatch 'saved on branch "main"') { Write-Output "expected branch warning, got: $out"; exit 1 }
  if ($out -notmatch '"feature/x"') { Write-Output "expected current branch in warning, got: $out"; exit 1 }
  Write-Output "branch mismatch: warned"

  # --- unknown base_commit: cannot verify, exit 0 ---
  (Get-Content h.md) -replace '^base_commit: .*', 'base_commit: 0123456789abcdef0123456789abcdef01234567' | Set-Content h.md
  $out = (& $check -File h.md) -join "`n"
  if ($out -notmatch 'cannot verify') { Write-Output "expected cannot-verify, got: $out"; exit 1 }
  Write-Output "unknown base: cannot verify"

  # --- legacy handoff without metadata: silent ---
  Copy-Item $example legacy.md
  $out = & $check -File legacy.md
  if ($out) { Write-Output "expected silence for legacy handoff, got: $out"; exit 1 }
  Write-Output "legacy: silent"

  # --- outside git: silent ---
  $nogit = Join-Path $work "nogit"
  New-Item -ItemType Directory -Path $nogit | Out-Null
  Copy-Item h.md (Join-Path $nogit "h.md")
  Set-Location $nogit
  $env:GIT_CEILING_DIRECTORIES = $work
  $out = & $check -File h.md
  $env:GIT_CEILING_DIRECTORIES = $null
  if ($out) { Write-Output "expected silence outside git, got: $out"; exit 1 }
  Write-Output "non-git: silent"

  # --- age warning fires even without git (mtime-based) ---
  Copy-Item $example old.md
  (Get-Item old.md).LastWriteTime = (Get-Date).AddDays(-10)
  $env:GIT_CEILING_DIRECTORIES = $work
  $out = (& $check -File old.md) -join "`n"
  $env:GIT_CEILING_DIRECTORIES = $null
  if ($out -notmatch 'day\(s\) old') { Write-Output "expected age warning, got: $out"; exit 1 }
  if ($out -notmatch 'saved_at:') { Write-Output "expected saved_at in warning, got: $out"; exit 1 }
  Write-Output "non-git stale: age warning"

  # --- HANDOFF_STALE_DAYS=0 disables the age check ---
  $env:GIT_CEILING_DIRECTORIES = $work
  $env:HANDOFF_STALE_DAYS = "0"
  $out = & $check -File old.md
  $env:HANDOFF_STALE_DAYS = $null
  $env:GIT_CEILING_DIRECTORIES = $null
  if ($out) { Write-Output "STALE_DAYS=0 should disable age check, got: $out"; exit 1 }
  Write-Output "age check: disable works"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

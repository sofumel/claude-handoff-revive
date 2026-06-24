# resume-receipt.ps1: reports the load boundary without echoing handoff body text.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$receipt = Join-Path $scriptsDir "resume-receipt.ps1"
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
  Copy-Item $example .claude-handoff.md
  & $inject -File .claude-handoff.md

  $out = (& $receipt -File .claude-handoff.md) -join "`n"
  if ($out -notmatch '\[handoff-revive\] resume receipt') { Write-Output "missing heading: $out"; exit 1 }
  if ($out -notmatch 'loaded: current.md only') { Write-Output "missing load boundary: $out"; exit 1 }
  if ($out -notmatch 'not_loaded: prior transcript; history snapshots; other handoff files') { Write-Output "missing not_loaded boundary: $out"; exit 1 }
  if ($out -notmatch 'sections_present: .*goal') { Write-Output "missing section names: $out"; exit 1 }
  if ($out -notmatch 'next_action_present: true') { Write-Output "missing next_action presence: $out"; exit 1 }
  if ($out -notmatch 'freshness: ok') { Write-Output "expected fresh receipt: $out"; exit 1 }
  if ($out -notmatch 'handoff_body_echoed=false') { Write-Output "missing privacy flag: $out"; exit 1 }
  if ($out -match 'ユーザー認証') { Write-Output "receipt leaked handoff body content"; exit 1 }

  git commit -q --allow-empty -m c2
  $out = (& $receipt -File .claude-handoff.md) -join "`n"
  if ($out -notmatch 'freshness: warnings=1') { Write-Output "expected one freshness warning: $out"; exit 1 }
  Write-Output "resume receipt: ok"
  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

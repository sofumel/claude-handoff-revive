# Sanitization (feature ⑯), PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$sanitize = Join-Path $scriptsDir "sanitize-handoff.ps1"
$share = Join-Path $scriptsDir "share-to-pr.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $work "repo\bin") -Force | Out-Null
$origLoc = Get-Location
$origPath = $env:Path

try {
  Set-Location (Join-Path $work "repo")
  git init -q -b main
  git config user.name "Test"
  git config user.email "t@example.com"
  git commit -q --allow-empty -m init
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null
  $root = (git rev-parse --show-toplevel)

  # --- path replacement + author_email removal ---
  Copy-Item $example h.md
  (Get-Content h.md -Raw) -replace '(?m)^lang: ja$', "lang: ja`nauthor: `"Keep Me`"`nauthor_email: `"private@example.com`"" | Set-Content h.md -NoNewline
  Add-Content h.md "`n- $root/src/deep.ts -- absolute project path`n- $HOME/other/file.ts -- home path"
  & $sanitize -File h.md
  $c = Get-Content h.md -Raw
  if ($c -notmatch '- <project-root>/src/deep\.ts') { Write-Output "project root not replaced"; exit 1 }
  if ($c -notmatch '- ~/') { Write-Output "home not replaced"; exit 1 }
  if ($c -match '(?m)^author_email:') { Write-Output "author_email must be stripped"; exit 1 }
  if ($c -notmatch '(?m)^author: "Keep Me"\r?$') { Write-Output "author must be kept"; exit 1 }
  Write-Output "paths: replaced; author_email: stripped"

  # --- secret detection: exit 2, NOT modified ---
  Copy-Item $example s.md
  Add-Content s.md '- config.ts -- contains sk-TESTFAKE00000000000000000000 key'
  & $sanitize -File s.md *> $null
  if ($LASTEXITCODE -ne 2) { Write-Output "expected exit 2, got $LASTEXITCODE"; exit 1 }
  if ((Get-Content s.md -Raw) -notmatch 'sk-TESTFAKE00000000000000000000') { Write-Output "secret must NOT be auto-redacted"; exit 1 }
  Write-Output "secrets: detected, not redacted"

  # --- documented boundary: generic strings pass ---
  Copy-Item $example b.md
  Add-Content b.md '- note.md -- password hunter2 and hex deadbeefcafebabe1234567890abcdef'
  & $sanitize -File b.md *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "generic strings must not trip detection"; exit 1 }
  Write-Output "boundary: generic strings pass (documented false negative)"

  # --- patterns come from lib/secret-patterns.txt (second family proves it) ---
  Copy-Item $example g.md
  Add-Content g.md '- ci.yml -- token ghp_FAKE000000000000000000000000000000'
  & $sanitize -File g.md *> $null
  if ($LASTEXITCODE -ne 2) { Write-Output "ghp_ pattern not detected - patterns file not read?"; exit 1 }
  Write-Output "patterns file: second family detected"

  # --- share aborts on secrets; -NoSanitize overrides ---
  $ghLog = Join-Path $work "gh.log"
  New-Item -ItemType File -Path $ghLog -Force | Out-Null
  $bat = @(
    "@echo off",
    "echo %* >> `"$ghLog`"",
    "if `"%1 %2`"==`"pr view`" echo 42",
    "exit /b 0"
  ) -join "`r`n"
  Set-Content -Path "bin\gh.bat" -Value $bat -Encoding ascii
  $env:Path = (Join-Path (Get-Location).Path "bin") + ";" + $env:Path

  Copy-Item s.md ".claude\handoff\current.md" -Force
  & $share *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "share must abort on secrets"; exit 1 }
  if ((Get-Content $ghLog -Raw) -match 'pr comment') { Write-Output "nothing should be posted on abort"; exit 1 }
  Write-Output "share: aborted on secrets"

  & $share -NoSanitize *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "-NoSanitize should post"; exit 1 }
  if ((Get-Content $ghLog -Raw) -notmatch 'pr comment 42') { Write-Output "-NoSanitize did not post: $(Get-Content $ghLog -Raw)"; exit 1 }
  Write-Output "share: -NoSanitize override works"

  # --- local handoff untouched by share's sanitization copy ---
  if ((Get-Content ".claude\handoff\current.md" -Raw) -notmatch 'sk-TESTFAKE00000000000000000000') { Write-Output "share must not modify the local handoff"; exit 1 }
  Write-Output "share: local file untouched"

  exit 0
} finally {
  $env:Path = $origPath
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

# share-to-pr.ps1 (feature ⑭), with a stubbed gh CLI (bat shim on PATH):
#   - dry-run prints the body and posts nothing
#   - real run posts via gh pr comment with auto-detected PR number
#   - explicit PR number is used as-is

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$share = Join-Path $scriptsDir "share-to-pr.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $work "bin") -Force | Out-Null
$origLoc = Get-Location
$origPath = $env:Path

try {
  Set-Location $work
  New-Item -ItemType Directory -Path ".claude\handoff" -Force | Out-Null
  Copy-Item $example ".claude\handoff\current.md"
  $ghLog = Join-Path $work "gh.log"
  New-Item -ItemType File -Path $ghLog | Out-Null

  # Stub gh as a .bat shim (resolves via PATH for both pwsh and powershell).
  $bat = @(
    "@echo off",
    "echo %* >> `"$ghLog`"",
    "if `"%1 %2`"==`"pr view`" echo 42",
    "exit /b 0"
  ) -join "`r`n"
  Set-Content -Path (Join-Path $work "bin\gh.bat") -Value $bat -Encoding ascii
  $env:Path = (Join-Path $work "bin") + ";" + $env:Path

  # --- dry-run: body shown, gh pr comment NOT called ---
  Clear-Content $ghLog
  $out = (& $share -DryRun) -join "`n"
  if ($out -notmatch 'would post the following to PR #42') { Write-Output "dry-run missing PR number: $out"; exit 1 }
  if ($out -notmatch '## goal') { Write-Output "dry-run missing handoff content"; exit 1 }
  if ((Get-Content $ghLog -Raw) -match 'pr comment') { Write-Output "dry-run must not post"; exit 1 }
  Write-Output "dry-run: shown, not posted"

  # --- real run: posts to auto-detected PR ---
  Clear-Content $ghLog
  $out = (& $share) -join "`n"
  if ($out -notmatch 'posted handoff context to PR #42') { Write-Output "post confirmation missing: $out"; exit 1 }
  if ((Get-Content $ghLog -Raw) -notmatch 'pr comment 42 --body-file') { Write-Output "gh pr comment not called: $(Get-Content $ghLog -Raw)"; exit 1 }
  Write-Output "real run: posted to auto-detected PR"

  # --- explicit PR number wins ---
  Clear-Content $ghLog
  & $share -Pr 7 | Out-Null
  if ((Get-Content $ghLog -Raw) -notmatch 'pr comment 7 --body-file') { Write-Output "explicit PR not used: $(Get-Content $ghLog -Raw)"; exit 1 }
  Write-Output "explicit PR: used"

  exit 0
} finally {
  $env:Path = $origPath
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

# preview-handoff.ps1: shows summary + content, flags invalid files,
# and never modifies the handoff.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$preview = Join-Path $scriptsDir "preview-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

try {
  $h = Join-Path $work "h.md"
  Copy-Item $example $h
  $before = (Get-FileHash $h -Algorithm SHA256).Hash

  $out = (& $preview -File $h) -join "`n"
  if ($out -notmatch 'validation: OK') { Write-Output "expected validation OK"; exit 1 }
  if ($out -notmatch '~\d+ tokens') { Write-Output "expected token estimate"; exit 1 }
  if ($out -notmatch '## goal') { Write-Output "expected content section"; exit 1 }
  Write-Output "valid file: summary + content"

  $after = (Get-FileHash $h -Algorithm SHA256).Hash
  if ($before -ne $after) { Write-Output "preview modified the file"; exit 1 }
  Write-Output "read-only: file unchanged"

  $bad = Join-Path $work "bad.md"
  "garbage" | Set-Content $bad
  $out = (& $preview -File $bad) -join "`n"
  if ($out -notmatch 'validation: INVALID') { Write-Output "expected INVALID flag"; exit 1 }
  Write-Output "invalid file: flagged, still exits 0"

  exit 0
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

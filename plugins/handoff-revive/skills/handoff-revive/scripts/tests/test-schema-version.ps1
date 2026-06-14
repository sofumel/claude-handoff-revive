# schema_version gate in validate-handoff.ps1:
#   - "1.0" (shipped example) accepted
#   - missing schema_version accepted (legacy v1.0 handoffs)
#   - non-1.x version rejected

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$validate = Join-Path $scriptsDir "validate-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

try {
  # --- example ships with schema_version: "1.0" and passes ---
  $raw = Get-Content $example -Raw
  if ($raw -notmatch '(?m)^schema_version: "1\.0"$') { Write-Output "example.md is missing schema_version"; exit 1 }
  & $validate -File $example *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output 'version "1.0" was rejected'; exit 1 }
  Write-Output 'version "1.0": accepted'

  # --- legacy handoff without schema_version still passes ---
  $legacy = Join-Path $work "legacy.md"
  (Get-Content $example) | Where-Object { $_ -notmatch '^schema_version:' } | Set-Content $legacy
  & $validate -File $legacy *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "legacy handoff was rejected"; exit 1 }
  Write-Output "missing version (legacy): accepted"

  # --- future minor version (1.5) passes ---
  $minor = Join-Path $work "minor.md"
  ($raw -replace '(?m)^schema_version: "1\.0"$', 'schema_version: "1.5"') | Set-Content $minor -NoNewline
  & $validate -File $minor *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output 'version "1.5" was rejected'; exit 1 }
  Write-Output 'version "1.5": accepted'

  # --- unsupported major version rejected ---
  $future = Join-Path $work "future.md"
  ($raw -replace '(?m)^schema_version: "1\.0"$', 'schema_version: "9.9"') | Set-Content $future -NoNewline
  & $validate -File $future *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output 'version "9.9" should have been rejected'; exit 1 }
  Write-Output 'version "9.9": rejected as expected'

  exit 0
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

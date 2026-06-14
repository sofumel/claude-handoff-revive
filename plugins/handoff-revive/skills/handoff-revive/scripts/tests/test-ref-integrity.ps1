# Reference integrity (feature ⑫), PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$validate = Join-Path $scriptsDir "validate-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

# The validator writes warnings via [Console]::Error, which an in-process call
# cannot capture with 2>&1. Spawn a child shell (same as the real invocation).
$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
function Invoke-Validate {
  param([string[]]$validateArgs)
  $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $validate @validateArgs 2>&1 | Out-String
  return $out
}

try {
  Set-Location $work
  Copy-Item $example h.md

  # Create every path the example references.
  New-Item -ItemType Directory -Path "src\auth", "tests\auth", "tests\integration" -Force | Out-Null
  foreach ($f in @("src\auth\login.ts", "src\auth\safe-compare.ts", "src\auth\password-reset.ts", "tests\auth\safe-compare.test.ts", "CHANGELOG.md")) {
    New-Item -ItemType File -Path $f -Force | Out-Null
  }

  # --- all refs exist: OK, no warnings ---
  $err = Invoke-Validate @("-File", "h.md")
  if ($LASTEXITCODE -ne 0) { Write-Output "validate failed: $err"; exit 1 }
  if ($err -match 'referenced path') { Write-Output "unexpected warning: $err"; exit 1 }
  Write-Output "all refs exist: clean"

  # --- missing touched_files path: lenient warns, exit 0 ---
  Remove-Item CHANGELOG.md
  $err = Invoke-Validate @("-File", "h.md")
  if ($LASTEXITCODE -ne 0) { Write-Output "lenient mode must keep exit 0"; exit 1 }
  if ($err -notmatch 'referenced path does not exist: CHANGELOG\.md') { Write-Output "expected warning, got: $err"; exit 1 }
  Write-Output "missing path (lenient): warned, exit 0"

  # --- strict: missing path is an error ---
  Invoke-Validate @("-File", "h.md", "-Strict") | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-Output "-Strict should have failed"; exit 1 }
  Write-Output "missing path (strict): rejected"

  # --- 'planned:' reason bypasses even strict ---
  (Get-Content h.md) -replace '^- CHANGELOG\.md -- .*', '- CHANGELOG.md -- planned: security セクションに追記予定' | Set-Content h.md
  Invoke-Validate @("-File", "h.md", "-Strict") | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Output "planned: reason should bypass strict"; exit 1 }
  Write-Output "planned reason: bypassed"

  # --- '# planned:' line in next_action bypasses ---
  Remove-Item "src\auth\login.ts"
  (Get-Content h.md) -replace '^Edit src/auth/login\.ts:42', '# planned: Edit src/auth/login.ts:42' | Set-Content h.md
  $err = Invoke-Validate @("-File", "h.md")
  if ($LASTEXITCODE -ne 0) { Write-Output "should still be valid"; exit 1 }
  if ($err -match 'next_action') { Write-Output "planned line should bypass next_action check: $err"; exit 1 }
  Write-Output "planned line: bypassed"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

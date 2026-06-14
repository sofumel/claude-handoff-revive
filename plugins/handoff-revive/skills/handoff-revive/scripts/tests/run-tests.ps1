# Local test runner: executes every test-*.ps1 in this directory and reports a summary.
# Pure PowerShell, no external test framework. Exit 0 = all pass, 1 = at least one failure.
#
# Usage:
#   .\run-tests.ps1               # run all tests
#   .\run-tests.ps1 validate      # run only test-validate.ps1
#
# The deep invalid-case matrix lives in the bash tests (test-validate.sh);
# these tests cover the PowerShell ports of the same scripts.
# NOTE: this directory is dev-only — install.sh / install.ps1 exclude it.

param(
  [string]$Pattern = ""
)

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) {
  $dir = $PSScriptRoot
} else {
  $dir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

$pass = 0
$fail = 0
$failedNames = @()

Get-ChildItem -Path $dir -Filter "test-*.ps1" | Sort-Object Name | ForEach-Object {
  $name = $_.BaseName
  if ($Pattern -and ($name -notlike "*$Pattern*")) { return }
  Write-Output "== $name"
  $output = & $_.FullName 2>&1
  if ($LASTEXITCODE -eq 0) {
    $script:pass++
    Write-Output "   PASS"
  } else {
    $script:fail++
    $script:failedNames += $name
    Write-Output "   FAIL"
    $output | ForEach-Object { Write-Output "   | $_" }
  }
}

$total = $pass + $fail
if ($total -eq 0) {
  Write-Output "No tests matched."
  exit 1
}

Write-Output "----------------------------------------"
Write-Output "$pass/$total passed"
if ($fail -gt 0) {
  Write-Output "failed: $($failedNames -join ', ')"
  exit 1
}
exit 0

# Regression: CRLF secret-patterns.txt must not disable secret detection.
# PowerShell's Get-Content + .Trim() already strip CR; this locks that contract
# so a future refactor cannot reintroduce the Windows-clone failure mode.
$ErrorActionPreference = "Stop"

$testsDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir  = Split-Path -Parent $testsDir
$skillDir    = Split-Path -Parent $scriptsDir
$example     = Join-Path $skillDir "templates\example.md"
$sanitizeSrc = Join-Path $scriptsDir "sanitize-handoff.ps1"
$patternsSrc = Join-Path $scriptsDir "lib\secret-patterns.txt"

$work = Join-Path ([IO.Path]::GetTempPath()) ("hr-crlf-" + [Guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Force -Path (Join-Path $work "scripts\lib") | Out-Null
  Copy-Item $sanitizeSrc (Join-Path $work "scripts\sanitize-handoff.ps1")
  $crlf = ((Get-Content $patternsSrc) -join "`r`n") + "`r`n"
  [IO.File]::WriteAllText((Join-Path $work "scripts\lib\secret-patterns.txt"), $crlf)

  $h = Join-Path $work "h.md"
  Copy-Item $example $h
  Add-Content -Path $h -Value "- config.ts -- contains sk-TESTFAKE00000000000000000000 key"

  & (Join-Path $work "scripts\sanitize-handoff.ps1") -File $h *> $null
  if ($LASTEXITCODE -ne 2) {
    Write-Output "FAIL: CRLF patterns must still detect the secret (got exit $LASTEXITCODE)"
    exit 1
  }
  Write-Output "crlf patterns: secret still detected (exit 2)"
}
finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
exit 0
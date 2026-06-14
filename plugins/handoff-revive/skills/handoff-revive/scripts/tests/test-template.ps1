# Template variant (feature ⑮), PowerShell ports.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$validate = Join-Path $scriptsDir "validate-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

function Add-TemplateField {
  param($outFile, $templateName)
  (Get-Content $example -Raw) -replace '(?m)^schema_version: "1\.0"$', "schema_version: `"1.0`"`ntemplate: `"$templateName`"" |
    Set-Content $outFile -NoNewline
}

try {
  # --- valid vacation-handover passes ---
  $v = Join-Path $work "v.md"
  Add-TemplateField $v "vacation-handover"
  Add-Content $v "`n`n## handover_notes`n- contact: auth は @tanaka へ`n- deadline: 6/20 レビュー提出`n- watch_out: login.ts はテスト無しで触らない"
  & $validate -File $v *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "valid vacation-handover rejected"; exit 1 }
  Write-Output "vacation-handover: accepted"

  # --- missing handover_notes: rejected ---
  $m = Join-Path $work "m.md"
  Add-TemplateField $m "vacation-handover"
  & $validate -File $m *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "missing handover_notes should fail"; exit 1 }
  Write-Output "missing handover_notes: rejected"

  # --- unknown template: rejected ---
  $u = Join-Path $work "u.md"
  Add-TemplateField $u "no-such-template"
  & $validate -File $u *> $null
  if ($LASTEXITCODE -eq 0) { Write-Output "unknown template should fail"; exit 1 }
  Write-Output "unknown template: rejected"

  # --- no template field: default unchanged ---
  & $validate -File $example *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "default schema must stay valid"; exit 1 }
  Write-Output "no template field: default unchanged"

  exit 0
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

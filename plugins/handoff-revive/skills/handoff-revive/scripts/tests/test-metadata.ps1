# inject-metadata.ps1: git metadata lands in frontmatter, quoted, idempotent;
# outside git only created_at; HANDOFF_HIDE_EMAIL masks the email;
# the injected file still validates.

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $testsDir = $PSScriptRoot } else { $testsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$scriptsDir = Split-Path -Parent $testsDir
$skillDir = Split-Path -Parent $scriptsDir
$example = Join-Path $skillDir "templates\example.md"
$inject = Join-Path $scriptsDir "inject-metadata.ps1"
$validate = Join-Path $scriptsDir "validate-handoff.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$origLoc = Get-Location

try {
  # --- inside a git repo: all fields injected, author quoted ---
  $repo = Join-Path $work "repo"
  New-Item -ItemType Directory -Path $repo | Out-Null
  Set-Location $repo
  git init -q
  git config user.name "Test: User"   # ': ' on purpose - must be quoted away
  git config user.email "t@example.com"
  git commit -q --allow-empty -m init
  Copy-Item $example h.md

  & $inject -File h.md
  $c = Get-Content h.md
  if (-not ($c -contains 'author: "Test: User"')) { Write-Output "author missing or unquoted"; exit 1 }
  if (-not ($c -contains 'author_email: "t@example.com"')) { Write-Output "author_email missing"; exit 1 }
  $branch = (git rev-parse --abbrev-ref HEAD)
  if (-not ($c -contains "branch: `"$branch`"")) { Write-Output "branch missing"; exit 1 }
  $commit = (git rev-parse HEAD)
  if (-not ($c -contains "base_commit: $commit")) { Write-Output "base_commit missing"; exit 1 }
  if (-not ($c -match '^created_at: \d{4}-\d{2}-\d{2}T')) { Write-Output "created_at missing"; exit 1 }
  Write-Output "git repo: all fields injected"

  # --- idempotent: re-running keeps exactly one of each ---
  & $inject -File h.md
  $c = Get-Content h.md
  foreach ($f in @("author:", "author_email:", "branch:", "base_commit:", "created_at:")) {
    $n = @($c | Where-Object { $_ -match "^$([regex]::Escape($f))" }).Count
    if ($n -ne 1) { Write-Output "field $f duplicated ($n times)"; exit 1 }
  }
  Write-Output "idempotent: OK"

  # --- still validates after injection ---
  & $validate -File h.md *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "post-inject file no longer validates"; exit 1 }
  Write-Output "post-inject validate: OK"

  # --- HANDOFF_HIDE_EMAIL=1 omits the email ---
  Copy-Item $example h2.md
  $env:HANDOFF_HIDE_EMAIL = "1"
  & $inject -File h2.md
  $env:HANDOFF_HIDE_EMAIL = $null
  $c2 = Get-Content h2.md
  if ($c2 -match '^author_email:') { Write-Output "email should have been hidden"; exit 1 }
  if (-not ($c2 -match '^author:')) { Write-Output "author should still be present"; exit 1 }
  Write-Output "HANDOFF_HIDE_EMAIL: email omitted"

  # --- outside a git repo: only created_at, no crash ---
  # GIT_CEILING_DIRECTORIES stops upward discovery at $work: even if the temp
  # dir happens to live inside some repo (e.g. a git-init'ed home dir), the
  # script must behave as if there is no repo.
  $nogit = Join-Path $work "nogit"
  New-Item -ItemType Directory -Path $nogit | Out-Null
  Set-Location $nogit
  Copy-Item $example h.md
  $env:GIT_CEILING_DIRECTORIES = $work
  & $inject -File h.md
  $env:GIT_CEILING_DIRECTORIES = $null
  $c3 = Get-Content h.md
  if (-not ($c3 -match '^created_at:')) { Write-Output "created_at missing outside git"; exit 1 }
  if ($c3 -match '^(author|branch|base_commit):') { Write-Output "git fields should be absent outside git"; exit 1 }
  Write-Output "non-git: created_at only"

  exit 0
} finally {
  Set-Location $origLoc
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

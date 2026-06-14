# Per-branch handoff stash/restore (zero LLM tokens). See the .sh twin for
# the case table. Never destructive: anything about to be overwritten is
# archived to history/ first.

$ErrorActionPreference = "Continue"

$dir = ".claude/handoff"
$file = "$dir/current.md"
$branches = "$dir/branches"
if ($PSScriptRoot) { $self = $PSScriptRoot } else { $self = Split-Path -Parent $MyInvocation.MyCommand.Definition }

git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
  [Console]::Error.WriteLine("ERROR: not a git repository - per-branch handoffs need git.")
  exit 1
}
$currentBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
if (-not $currentBranch -or $currentBranch -eq "HEAD") {
  [Console]::Error.WriteLine("ERROR: detached HEAD - check out a branch first.")
  exit 1
}

$curSlug = $currentBranch -replace '/', '_'

function Restore-IfParked {
  $parked = Join-Path $branches "$curSlug.md"
  if (Test-Path $parked) {
    Move-Item $parked $file -Force
    Write-Output "[handoff-revive] restored the handoff parked for branch `"$currentBranch`"."
  } else {
    Write-Output "[handoff-revive] no handoff parked for branch `"$currentBranch`" - clean slate (save will create one)."
  }
}

if (-not (Test-Path $file)) {
  New-Item -ItemType Directory -Path $branches -Force | Out-Null
  Restore-IfParked
  exit 0
}

$savedBranch = ""
foreach ($l in (Get-Content $file)) {
  if ($l -match '^branch:\s*"?([^"]*?)"?\s*$') { $savedBranch = $matches[1]; break }
}
if (-not $savedBranch) {
  [Console]::Error.WriteLine("ERROR: current.md has no 'branch:' metadata (saved before v1.1?). Cannot route it safely - re-save it on its branch first.")
  exit 1
}

if ($savedBranch -eq $currentBranch) {
  Write-Output "[handoff-revive] current.md already belongs to `"$currentBranch`" - nothing to switch."
  exit 0
}

New-Item -ItemType Directory -Path $branches -Force | Out-Null
$savedSlug = $savedBranch -replace '/', '_'
$dest = Join-Path $branches "$savedSlug.md"

# Never destroy: if a stale parked copy exists for that branch, archive it.
if (Test-Path $dest) {
  try { & (Join-Path $self "archive-current.ps1") -File $dest *> $null } catch {}
  Remove-Item $dest -Force -ErrorAction SilentlyContinue
}
Move-Item $file $dest -Force
Write-Output "[handoff-revive] parked the `"$savedBranch`" handoff at branches/$savedSlug.md."

Restore-IfParked
exit 0

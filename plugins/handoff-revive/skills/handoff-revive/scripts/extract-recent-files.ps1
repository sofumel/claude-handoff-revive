# Output a list of recently-changed files as `- <path> -- <reason>` lines,
# ready to drop into the `## touched_files` section of a handoff file.
#
# Strategy:
#   1. If invoked inside a git repo: use `git status --porcelain` (uncommitted),
#      plus files committed during this session (git log --since=<.session-start>).
#      Pulled-in commits are excluded by limiting to @{u}..HEAD when an
#      upstream exists (local-only commits).
#   2. Otherwise: fall back to files modified in the last 60 minutes
#
# Excludes vendor/build directories. Caps at 20 entries.

param(
  [string]$Dir = "."
)

$ErrorActionPreference = "Stop"

Set-Location $Dir

$excludes = @(
  '.git', '.claude', 'node_modules', 'dist', 'build',
  '.venv', '__pycache__', '.next', '.nuxt', '.cache', 'target'
)
$limit = 20

function Test-Excluded([string]$path) {
  foreach ($ex in $excludes) {
    if ($path -eq $ex) { return $true }
    if ($path.StartsWith("$ex/") -or $path.StartsWith("$ex\")) { return $true }
  }
  return $false
}

# (Approved-verb naming: "Map" is not a PowerShell approved verb.)
function Get-StatusReason([string]$status) {
  switch -regex ($status) {
    '^M |^ M|^MM' { return 'modified' }
    '^A |^AM'     { return 'added' }
    '^ D|^D '     { return 'deleted' }
    '^R '         { return 'renamed' }
    '^\?\?'       { return 'untracked / new' }
    default       { return 'changed' }
  }
}

# Detect git repo by walking up looking for .git (avoids invoking the git CLI,
# whose stderr would trigger PS 5.1 NativeCommandError under ErrorActionPreference=Stop).
function Test-InGitRepo {
  $cur = (Get-Location).Path
  while ($cur) {
    if (Test-Path (Join-Path $cur ".git")) { return $true }
    $parent = Split-Path -Parent $cur
    if (-not $parent -or $parent -eq $cur) { return $false }
    $cur = $parent
  }
  return $false
}

$inGit = Test-InGitRepo

$emitted = 0

if ($inGit) {
  $seen = New-Object System.Collections.Generic.HashSet[string]
  $lines = git status --porcelain 2>$null
  if ($lines) {
    foreach ($line in $lines) {
      if ($emitted -ge $limit) { break }
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      if ($line.Length -lt 4) { continue }
      $status = $line.Substring(0, 2)
      $path = $line.Substring(3).Trim('"')
      if (Test-Excluded $path) { continue }
      $reason = Get-StatusReason $status
      Write-Output "- $path -- $reason"
      [void]$seen.Add($path)
      $emitted++
    }
  }

  # --- files committed during this session ---
  # .session-start (epoch) is written by the SessionStart hook. When an
  # upstream exists, only local-ahead commits (@{u}..HEAD) are scanned so
  # pulled-in changes don't pollute touched_files.
  $ssFile = ".claude/handoff/.session-start"
  if (Test-Path $ssFile) {
    $ss = (Get-Content $ssFile -Raw -ErrorAction SilentlyContinue)
    if ($ss) { $ss = $ss.Trim() }
    if ($ss -match '^\d+$') {
      $since = [DateTimeOffset]::FromUnixTimeSeconds([long]$ss).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
      git rev-parse '@{u}' *> $null
      $range = if ($LASTEXITCODE -eq 0) { '@{u}..HEAD' } else { 'HEAD' }
      $logLines = git log --since="$since" --name-only --pretty=format: --no-merges $range 2>$null
      foreach ($path in $logLines) {
        if ($emitted -ge $limit) { break }
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        if (Test-Excluded $path) { continue }
        if ($seen.Contains($path)) { continue }
        Write-Output "- $path -- committed this session"
        [void]$seen.Add($path)
        $emitted++
      }
    }
  }
} else {
  $cutoff = (Get-Date).AddMinutes(-60)
  $cwd = (Get-Location).Path
  Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $cutoff } |
    ForEach-Object {
      if ($emitted -ge $limit) { return }
      $rel = ($_.FullName.Substring($cwd.Length + 1)) -replace '\\', '/'
      if (Test-Excluded $rel) { return }
      Write-Output "- $rel -- modified within last hour"
      $emitted++
    }
}

exit 0

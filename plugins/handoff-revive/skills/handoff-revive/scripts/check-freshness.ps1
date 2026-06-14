# Freshness check for RESUME (zero LLM tokens): compares the handoff's
# base_commit / branch metadata against the current git state.
#
# Output (stdout): human-readable warning lines, or nothing when fresh.
# Exit code: always 0 unless the handoff file itself is missing.
# This script INFORMS - it never blocks a resume.
#
# Checks:
#   - age: warns when the file is older than HANDOFF_STALE_DAYS (default 7).
#     Based on file mtime, so it works WITHOUT git.
#   - git: commits since base_commit, branch mismatch (silent when the
#     handoff has no metadata - legacy save - or outside a git repository)

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: file not found: $File")
  exit 1
}

# --- Age check (git-independent) ---
$staleDays = 7
if ($env:HANDOFF_STALE_DAYS -match '^\d+$') { $staleDays = [int]$env:HANDOFF_STALE_DAYS }
if ($staleDays -gt 0) {
  $ageDays = ((Get-Date) - (Get-Item $File).LastWriteTime).TotalDays
  if ($ageDays -gt $staleDays) {
    $savedAt = "unknown"
    foreach ($l in (Get-Content $File)) {
      if ($l -match '^saved_at:\s*(.+?)\s*$') { $savedAt = $matches[1]; break }
    }
    Write-Output "[handoff-revive] freshness: this handoff is more than $staleDays day(s) old (saved_at: $savedAt). Its contents may be outdated."
  }
}

$content = Get-Content $File
$baseCommit = ""
$savedBranch = ""
foreach ($l in $content) {
  if (-not $baseCommit -and $l -match '^base_commit:\s*(\S+)\s*$') { $baseCommit = $matches[1] }
  if (-not $savedBranch -and $l -match '^branch:\s*"?([^"]*?)"?\s*$') { $savedBranch = $matches[1] }
}

# Legacy handoff without metadata, or outside git: stay silent.
if (-not $baseCommit) { exit 0 }
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }

# base_commit not present locally: report "cannot verify" but do not error.
git cat-file -e "$baseCommit^{commit}" *> $null
if ($LASTEXITCODE -ne 0) {
  $short = $baseCommit.Substring(0, [Math]::Min(12, $baseCommit.Length))
  Write-Output "[handoff-revive] freshness: cannot verify - base_commit $short not found in this repository (rebased, shallow clone, or different repo)."
  exit 0
}

# Commits since the handoff was saved.
$ahead = (git rev-list --count "$baseCommit..HEAD" 2>$null)
if ($ahead -and [int]$ahead -gt 0) {
  $short = $baseCommit.Substring(0, [Math]::Min(12, $baseCommit.Length))
  Write-Output "[handoff-revive] freshness: this handoff was saved $ahead commit(s) ago (base: $short). touched_files / next_action may no longer match the current code."
}

# Branch mismatch.
$currentBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
if ($savedBranch -and $currentBranch -and $currentBranch -ne "HEAD" -and $savedBranch -ne $currentBranch) {
  Write-Output "[handoff-revive] freshness: handoff was saved on branch `"$savedBranch`" but you are now on `"$currentBranch`". It may belong to different work."
}

exit 0

# Post the handoff as a PR comment so reviewers see the work context
# (goal / decisions / lessons_learned) next to the diff. Requires gh CLI.
#
# Usage:
#   share-to-pr.ps1                          # PR auto-detected from current branch
#   share-to-pr.ps1 -Pr 123                  # explicit PR number
#   share-to-pr.ps1 -DryRun [-Pr 123]        # print the comment body, post nothing
#   share-to-pr.ps1 -NoSanitize              # share the file as-is (not recommended)
#
# The body is built from a SANITIZED COPY by default; detected secrets abort
# the post. Sanitization is best-effort, not a security guarantee.
#
# Exit codes: 0 posted (or dry-run shown), 1 precondition failed.

param(
  [string]$Pr = "",
  [switch]$DryRun,
  [switch]$NoSanitize,
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Continue"

if ($PSScriptRoot) { $dirSelf = $PSScriptRoot } else { $dirSelf = Split-Path -Parent $MyInvocation.MyCommand.Definition }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  [Console]::Error.WriteLine("ERROR: the GitHub CLI (gh) is required. Install: https://cli.github.com/ then run 'gh auth login'.")
  exit 1
}

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: handoff not found: $File - run /handoff-revive:save first.")
  exit 1
}

if (-not $Pr) {
  $Pr = (gh pr view --json number --jq '.number' 2>$null)
  if (-not $Pr) {
    [Console]::Error.WriteLine("ERROR: no PR found for the current branch. Pass a PR number: share-to-pr.ps1 -Pr <number>")
    exit 1
  }
}

# Work on a sanitized COPY - the local handoff is never modified here.
$shareSrc = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-share-" + [guid]::NewGuid().ToString("N") + ".md")
Copy-Item $File $shareSrc

if (-not $NoSanitize) {
  & (Join-Path $dirSelf "sanitize-handoff.ps1") -File $shareSrc
  if ($LASTEXITCODE -eq 2) {
    [Console]::Error.WriteLine("ERROR: likely secrets detected in the handoff (see warnings above). Remove them and re-save, or override with -NoSanitize at your own risk.")
    Remove-Item $shareSrc -ErrorAction SilentlyContinue
    exit 1
  } elseif ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("ERROR: sanitization failed (exit $LASTEXITCODE).")
    Remove-Item $shareSrc -ErrorAction SilentlyContinue
    exit 1
  }
}

$body = @()
$body += "## 🤝 Handoff context"
$body += ""
$body += "Work-state checkpoint for this branch, saved by [claude-handoff-revive](https://github.com/sofumel/claude-handoff-revive):"
$body += ""
$body += (Get-Content $shareSrc)
$body += ""
Remove-Item $shareSrc -ErrorAction SilentlyContinue
$body += "---"
$body += "_🤖 Posted by claude-handoff-revive (``/handoff-revive:share-to-pr``)_"
$bodyText = $body -join "`n"

# GitHub comment hard limit is 65536 chars; stay well below.
if ($bodyText.Length -gt 60000) {
  [Console]::Error.WriteLine("ERROR: comment body is $($bodyText.Length) chars (>60000). Trim the handoff before sharing.")
  exit 1
}

if ($DryRun) {
  Write-Output "[handoff-revive] dry-run: would post the following to PR #$Pr"
  Write-Output "---------------------------------------------"
  Write-Output $bodyText
  exit 0
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-pr-" + [guid]::NewGuid().ToString("N") + ".md")
try {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($tmp, $bodyText, $utf8NoBom)
  gh pr comment $Pr --body-file $tmp
  if ($LASTEXITCODE -ne 0) { exit 1 }
  Write-Output "[handoff-revive] posted handoff context to PR #$Pr"
  exit 0
} finally {
  Remove-Item $tmp -ErrorAction SilentlyContinue
}

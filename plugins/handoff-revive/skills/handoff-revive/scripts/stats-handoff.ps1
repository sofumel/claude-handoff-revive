# Save/resume statistics (zero LLM tokens). Records events in
# .claude/handoff/.stats ("<epoch> <kind> <bytes>" per line) and reports
# totals with an HONEST, assumption-labelled savings estimate.
#
# Usage:
#   stats-handoff.ps1 record save [-File path]
#   stats-handoff.ps1 record resume [-File path]
#   stats-handoff.ps1 show

param(
  [string]$Cmd = "show",
  [string]$Kind = "",
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Continue"

$dir = ".claude/handoff"
$stats = "$dir/.stats"

switch ($Cmd) {
  "record" {
    if ($Kind -ne "save" -and $Kind -ne "resume") {
      [Console]::Error.WriteLine("ERROR: usage: stats-handoff.ps1 record save|resume [-File path]")
      exit 1
    }
    if (-not (Test-Path $File)) { exit 0 }   # nothing to measure; never block
    $bytes = (Get-Item $File).Length
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    Add-Content -Path $stats -Value "$epoch $Kind $bytes"
    exit 0
  }
  "show" {
    if (-not (Test-Path $stats)) {
      Write-Output "[handoff-revive] no stats yet - they accumulate from your next save."
      exit 0
    }
    $saves = 0; $resumes = 0; $saveBytes = [long]0; $resumeBytes = [long]0
    foreach ($line in (Get-Content $stats)) {
      $p = $line -split '\s+'
      if ($p.Count -lt 3 -or $p[2] -notmatch '^\d+$') { continue }
      if ($p[1] -eq "save")   { $saves++;   $saveBytes += [long]$p[2] }
      if ($p[1] -eq "resume") { $resumes++; $resumeBytes += [long]$p[2] }
    }
    $resumeTokens = [long]($resumeBytes / 4)
    Write-Output "[handoff-revive] stats"
    $avg = if ($saves -gt 0) { "  (avg handoff ~$([long]($saveBytes / 4 / $saves)) tokens)" } else { "" }
    Write-Output "  saves:   $saves$avg"
    Write-Output "  resumes: $resumes  (total ~$resumeTokens tokens loaded instead of full transcripts)"
    if ($resumes -gt 0) {
      $low = [Math]::Max(0, $resumes * 30000 - $resumeTokens)
      $high = $resumes * 100000 - $resumeTokens
      Write-Output "  estimated savings vs --resume: ~$low to ~$high tokens"
      Write-Output "  (ASSUMPTION: a --resume replay costs 30k-100k tokens per session; actual prior-session sizes are unknowable from here)"
    }
    exit 0
  }
  default {
    [Console]::Error.WriteLine("ERROR: unknown subcommand: $Cmd (use: record save|resume, show)")
    exit 1
  }
}

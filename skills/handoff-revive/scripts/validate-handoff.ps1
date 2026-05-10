# Validate a handoff file against the schema deterministically (zero LLM tokens).
# Exit 0 = valid, 1 = invalid (errors to stderr).
#
# Usage:
#   validate-handoff.ps1                            # validates .claude\handoff\current.md
#   validate-handoff.ps1 -File path\to\handoff.md   # validates given path

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: file not found: $File")
  exit 1
}

$content = Get-Content $File -Raw
# Strip UTF-8 BOM if present (some editors add it; doesn't affect validity).
if ($content -and $content.Length -gt 0 -and [int][char]$content[0] -eq 0xFEFF) {
  $content = $content.Substring(1)
}
$errors = @()

# --- Frontmatter ---
if ($content -notmatch '^---\s*\r?\n') {
  $errors += "missing YAML frontmatter (file must start with '---')"
} else {
  # Find first closing '---' or first '## ' section, whichever comes first.
  $lines = $content -split "`r?`n"
  $closed = $false
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^---\s*$') { $closed = $true; break }
    if ($lines[$i] -match '^## ') { break }
  }
  if (-not $closed) {
    $errors += "YAML frontmatter is not closed (need a '---' line before the first '## ' section)"
  }
}
if ($content -notmatch '(?m)^saved_at:\s*\S') {
  $errors += "missing or empty 'saved_at:' in frontmatter"
}
if ($content -notmatch '(?m)^lang:\s*(ja|en|zh|zh-TW|ko|es|pt|de|fr|tr)\s*$') {
  $errors += "missing or invalid 'lang:' (must be one of: ja, en, zh, zh-TW, ko, es, pt, de, fr, tr)"
}

# --- Required sections ---
$required = @('goal', 'done', 'wip', 'todo', 'next_action', 'touched_files', 'decisions')
foreach ($s in $required) {
  if ($content -notmatch "(?m)^## $s\s*$") {
    $errors += "missing required section: ## $s"
  }
}

# --- Section extractor ---
function Get-Section {
  param($content, $name)
  $pattern = "(?ms)^## $name\s*$\r?\n(.*?)(?=^## |\z)"
  if ($content -match $pattern) { return $matches[1] }
  return ""
}

# next_action
$nextAction = Get-Section $content "next_action"
$nextActionStripped = ($nextAction -replace '\s', '')
if ($nextActionStripped.Length -eq 0) {
  $errors += "'next_action' section is empty - must contain executable instructions"
} elseif ($nextAction -notmatch '\S+:\d+') {
  $errors += "'next_action' must contain a 'file:line' pattern (e.g., 'src/foo.ts:42')"
}

# touched_files: every '- ...' entry must contain ' -- ' separator.
$touched = Get-Section $content "touched_files"
$bad = ($touched -split "`r?`n") | Where-Object { $_ -match '^-\s+\S' -and $_ -notmatch ' -- ' }
if ($bad.Count -gt 0) {
  $errors += "'touched_files' entries must use ' -- ' separator (offending: $($bad[0]))"
}

# Template placeholders
$phMatches = [regex]::Matches($content, '\{[A-Za-z_][^}]*\}')
if ($phMatches.Count -gt 0) {
  $unique = ($phMatches | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ' '
  $errors += "leftover template placeholders: $unique"
}

# goal non-empty
$goal = Get-Section $content "goal"
if (($goal -replace '\s', '').Length -eq 0) {
  $errors += "'goal' section is empty"
}

# --- Output ---
if ($errors.Count -eq 0) {
  Write-Output "OK"
  exit 0
}

[Console]::Error.WriteLine("INVALID ($($errors.Count) issue(s)):")
foreach ($e in $errors) {
  [Console]::Error.WriteLine("  - $e")
}
exit 1

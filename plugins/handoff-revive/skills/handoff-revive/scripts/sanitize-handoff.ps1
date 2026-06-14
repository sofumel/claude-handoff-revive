# Sanitize a handoff for sharing (zero LLM tokens). BEST-EFFORT ONLY -
# this is a convenience pass, NOT a security guarantee. The user remains
# responsible for reviewing shared content.
#
#   1. REMOVES the `author_email:` metadata line (personal data; share-to-pr
#      operates on a temp copy, so the local handoff keeps it).
#   2. AUTO-REPLACES machine-local paths: <project git root> -> <project-root>,
#      $HOME -> ~ (both path spellings).
#   3. DETECTS likely secrets and reports them with line numbers. NEVER
#      auto-replaces secrets.
#
# Known NOT detected: generic passwords, unprefixed random strings,
# secrets split across lines.
#
# Exit codes: 0 = clean, 1 = file missing, 2 = likely secrets detected.

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: file not found: $File")
  exit 1
}

# --- 1. drop author_email (personal data; never belongs in shared output) ---
$kept = (Get-Content $File) | Where-Object { $_ -notmatch '^author_email:' }
$utf8NoBomPre = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines((Resolve-Path $File).Path, $kept, $utf8NoBomPre)

# --- 2. path replacement (literal string .Replace, no regex pitfalls) ---
$content = Get-Content $File -Raw

git rev-parse --show-toplevel *> $null
$projectRoot = if ($LASTEXITCODE -eq 0) { (git rev-parse --show-toplevel 2>$null) } else { (Get-Location).Path }
$homeDir = $HOME

# Most specific first: project root (both separators), then home.
if ($projectRoot) {
  $rootFwd = $projectRoot -replace '\\', '/'
  $rootBack = $projectRoot -replace '/', '\'
  $content = $content.Replace($rootBack, '<project-root>').Replace($rootFwd, '<project-root>')
}
if ($homeDir) {
  $homeFwd = $homeDir -replace '\\', '/'
  $homeBack = $homeDir -replace '/', '\'
  $content = $content.Replace($homeBack, '~').Replace($homeFwd, '~')
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Resolve-Path $File).Path, $content, $utf8NoBom)

# --- 3. secret detection (warn-only; conservative known-prefix patterns) ---
# Patterns live in lib/secret-patterns.txt - the single source shared with
# the bash twin, so the two implementations cannot drift.
if ($PSScriptRoot) { $selfDir = $PSScriptRoot } else { $selfDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$patternsFile = Join-Path $selfDir "lib\secret-patterns.txt"
if (-not (Test-Path $patternsFile)) {
  [Console]::Error.WriteLine("ERROR: $patternsFile is missing - broken install.")
  exit 1
}
$patterns = @()
foreach ($line in (Get-Content $patternsFile)) {
  $t = $line.Trim()
  if (-not $t -or $t.StartsWith('#')) { continue }
  $patterns += $t
}
$secretPattern = '(' + ($patterns -join '|') + ')'

$found = @()
$lineNo = 0
foreach ($line in (Get-Content $File)) {
  $lineNo++
  foreach ($m in [regex]::Matches($line, $secretPattern)) {
    $excerpt = $m.Value.Substring(0, [Math]::Min(10, $m.Value.Length))
    $found += "  line ${lineNo}: ${excerpt}..."
  }
}

if ($found.Count -gt 0) {
  [Console]::Error.WriteLine("[sanitize-handoff] WARNING: likely secrets detected (NOT auto-redacted - remove or rotate them yourself):")
  foreach ($f in $found) { [Console]::Error.WriteLine($f) }
  [Console]::Error.WriteLine("[sanitize-handoff] Detection is best-effort (known prefixes only). Generic passwords and unprefixed random strings are NOT detected.")
  exit 2
}

exit 0

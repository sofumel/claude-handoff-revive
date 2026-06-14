# Inject git metadata into the handoff YAML frontmatter (zero LLM tokens).
# Called by finalize-handoff after cleanup; can also be run standalone.
#
# Fields written: author, author_email, branch, base_commit, created_at.
#   - author / author_email / branch are double-quoted: an unquoted value
#     containing ': ' would be reparsed as a nested YAML mapping.
#   - Outside a git repo only created_at is written (best-effort, no crash).
#   - HANDOFF_HIDE_EMAIL=1 omits author_email.
# Idempotent: existing metadata lines are replaced, never duplicated.

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: file not found: $File")
  exit 1
}

$lines = Get-Content $File
if ($lines.Count -eq 0 -or $lines[0] -notmatch '^---\s*$') {
  # No frontmatter; validate-handoff reports that case. Silently skip.
  exit 0
}

$createdAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$author = ""; $email = ""; $branch = ""; $commit = ""
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -eq 0) {
  $author = (git config user.name 2>$null)
  $email  = (git config user.email 2>$null)
  $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
  $commit = (git rev-parse HEAD 2>$null)
}
if ($env:HANDOFF_HIDE_EMAIL -eq "1") { $email = "" }

# Escape backslashes and double quotes so injected values cannot break out
# of YAML double-quoted scalars.
function Esc {
  param($v)
  if ($null -eq $v) { return "" }
  return (($v -replace '\\', '\\') -replace '"', '\"')
}

$out = New-Object System.Collections.Generic.List[string]
$inFm = $false
$done = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
  $l = $lines[$i]
  if ($i -eq 0) { $inFm = $true; $out.Add($l); continue }
  if ($inFm -and -not $done -and $l -match '^---\s*$') {
    if ($author) { $out.Add('author: "' + (Esc $author) + '"') }
    if ($email)  { $out.Add('author_email: "' + (Esc $email) + '"') }
    if ($branch) { $out.Add('branch: "' + (Esc $branch) + '"') }
    if ($commit) { $out.Add("base_commit: $commit") }
    $out.Add("created_at: $createdAt")
    $inFm = $false; $done = $true
    $out.Add($l)
    continue
  }
  if ($inFm -and $l -match '^(author|author_email|branch|base_commit|created_at):') { continue }
  $out.Add($l)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines((Resolve-Path $File).Path, $out, $utf8NoBom)
exit 0

# Post-process a handoff file (zero LLM tokens):
#   B. Prune `touched_files` bullets pointing to files that no longer exist.
#   C. Strip empty sections (## header followed by no real content).
#
# Modifies the file in place. Exit 0 even if nothing to clean.

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: file not found: $File")
  exit 1
}

# Use UTF-8 without BOM for in-place rewrites.
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# --- Phase B: prune dead touched_files entries ---
$content = [IO.File]::ReadAllText($File)
# Strip UTF-8 BOM if present.
if ($content -and $content.Length -gt 0 -and [int][char]$content[0] -eq 0xFEFF) {
  $content = $content.Substring(1)
}
$lines = $content -split "`r?`n"
$out = New-Object 'System.Collections.Generic.List[string]'
$inTouched = $false
$inFence = $false
$pruned = 0

foreach ($line in $lines) {
  # Toggle fenced code block state — `## foo` inside a fence is not a header.
  if ($line -match '^(```|~~~)') {
    $inFence = -not $inFence
    [void]$out.Add($line)
    continue
  }
  if (-not $inFence) {
    if ($line -match '^## touched_files\s*$') {
      $inTouched = $true
      [void]$out.Add($line)
      continue
    }
    if ($line -match '^## ') {
      $inTouched = $false
      [void]$out.Add($line)
      continue
    }
  }
  if ($inTouched -and -not $inFence -and $line -match '^-\s+\S') {
    $body = $line -replace '^-\s+', ''
    $sep = $body.IndexOf(' -- ')
    $path = if ($sep -gt 0) { $body.Substring(0, $sep) } else { $body }
    if (Test-Path -LiteralPath $path) {
      [void]$out.Add($line)
    } else {
      $pruned++
    }
    continue
  }
  [void]$out.Add($line)
}

if ($pruned -gt 0) {
  [Console]::Error.WriteLine("[cleanup-handoff] pruned $pruned dead entries from touched_files")
}

[IO.File]::WriteAllText($File, ($out -join "`n"), $utf8NoBom)

# --- Phase C: strip empty sections ---
$content = [IO.File]::ReadAllText($File)
# Strip UTF-8 BOM if present.
if ($content -and $content.Length -gt 0 -and [int][char]$content[0] -eq 0xFEFF) {
  $content = $content.Substring(1)
}
$lines = $content -split "`r?`n"
$out = New-Object 'System.Collections.Generic.List[string]'

$inFm = $false
$fmDone = $false
$inFenceC = $false
$sectBuf = New-Object 'System.Collections.Generic.List[string]'
$sectName = ""
$sectHas = $false
$inSect = $false
$stripped = 0

# Required sections per the schema — never strip these even if empty.
$requiredSections = @('goal', 'done', 'wip', 'todo', 'next_action', 'touched_files', 'decisions')

function Flush-Section {
  if ($script:inSect) {
    if ($script:sectHas -or ($script:requiredSections -contains $script:sectName)) {
      foreach ($l in $script:sectBuf) { [void]$script:out.Add($l) }
    } else {
      $script:stripped++
    }
  }
  $script:sectBuf.Clear()
  $script:sectName = ""
  $script:sectHas = $false
  $script:inSect = $false
}

for ($i = 0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]

  if ($i -eq 0 -and $line -match '^---\s*$') {
    $inFm = $true
    [void]$out.Add($line)
    continue
  }
  if ($inFm -and $line -match '^---\s*$') {
    $inFm = $false
    $fmDone = $true
    [void]$out.Add($line)
    continue
  }
  if ($inFm) {
    [void]$out.Add($line)
    continue
  }

  # Toggle code-fence state. Fenced lines never count as headers and always
  # count as "real content" so the surrounding section is preserved.
  if ($line -match '^(```|~~~)') {
    $inFenceC = -not $inFenceC
    if ($inSect) {
      [void]$sectBuf.Add($line)
      $sectHas = $true
    } else {
      [void]$out.Add($line)
    }
    continue
  }

  if (-not $inFenceC -and $line -match '^## ') {
    Flush-Section
    [void]$sectBuf.Add($line)
    if ($line -match '^## (\S+)') { $sectName = $matches[1] } else { $sectName = "" }
    $inSect = $true
    $sectHas = $false
    continue
  }

  if ($inSect) {
    [void]$sectBuf.Add($line)
    $stripped_line = $line.Trim()
    if ($stripped_line -ne '' -and $stripped_line -ne '-' -and $stripped_line -ne '- ...') {
      $sectHas = $true
    }
    continue
  }

  [void]$out.Add($line)
}

Flush-Section

if ($stripped -gt 0) {
  [Console]::Error.WriteLine("[cleanup-handoff] stripped $stripped empty optional section(s)")
}

[IO.File]::WriteAllText($File, ($out -join "`n"), $utf8NoBom)

exit 0

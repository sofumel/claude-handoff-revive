# Section-wise diff between the current handoff and a history snapshot
# (zero LLM tokens). Default target: the newest snapshot whose content
# differs from current - i.e. effectively the previous save, because each
# save archives itself (the newest snapshot usually equals current).

param(
  [string]$Timestamp = "",
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: file not found: $File")
  exit 1
}
$histDir = Join-Path (Split-Path -Parent $File) "history"

# --- resolve the snapshot to compare against ---
$old = $null
if ($Timestamp) {
  $Timestamp = $Timestamp -replace '\.md$', ''
  $cand = Join-Path $histDir "$Timestamp.md"
  if (Test-Path $cand) {
    $old = Get-Item $cand
  } else {
    $m = @(Get-ChildItem -Path $histDir -Filter "$Timestamp*.md" -ErrorAction SilentlyContinue)
    if ($m.Count -ne 1) {
      [Console]::Error.WriteLine("ERROR: snapshot `"$Timestamp`" not found or ambiguous. Run list-history.ps1.")
      exit 1
    }
    $old = $m[0]
  }
} else {
  $currentRaw = Get-Content $File -Raw
  foreach ($f in (Get-ChildItem -Path $histDir -Filter "*.md" -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    if ((Get-Content $f.FullName -Raw) -ne $currentRaw) { $old = $f; break }
  }
  if (-not $old) {
    Write-Output "[handoff-revive] nothing to compare: no snapshot differs from the current handoff."
    exit 0
  }
}

function Get-Section {
  param($path, $name)
  $out = @(); $on = $false
  foreach ($l in (Get-Content $path)) {
    if ($l -match '^## ') { $on = ($l -match ('^## ' + [regex]::Escape($name) + '\s*$')); continue }
    if ($on) { $out += $l }
  }
  return $out
}

$sections = @()
foreach ($p in @($File, $old.FullName)) {
  foreach ($l in (Get-Content $p)) {
    if ($l -match '^## (.+?)\s*$') {
      if ($sections -notcontains $matches[1]) { $sections += $matches[1] }
    }
  }
}

Write-Output "[handoff-revive] diff: $($old.Name) -> current ($File)"

$changed = 0
foreach ($s in $sections) {
  $oldBody = Get-Section $old.FullName $s
  $newBody = Get-Section $File $s
  if (($oldBody -join "`n") -eq ($newBody -join "`n")) { continue }
  $changed++
  Write-Output "## $s"
  $cmp = Compare-Object -ReferenceObject @($oldBody) -DifferenceObject @($newBody)
  foreach ($c in $cmp) {
    if (-not $c.InputObject.Trim()) { continue }
    if ($c.SideIndicator -eq "<=") { Write-Output "  - $($c.InputObject)" }
    else { Write-Output "  + $($c.InputObject)" }
  }
}

if ($changed -eq 0) {
  Write-Output "  (sections identical - only frontmatter metadata differs)"
} else {
  Write-Output "$changed section(s) changed."
}
exit 0

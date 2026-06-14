# Snapshot the handoff into <dir>/history/<UTC-timestamp>.md (zero LLM tokens).
# Called by finalize-handoff after each successful save; safe standalone.
#
# - Collision-safe: a same-second snapshot bumps the timestamp by +1s until
#   free. Uniform digit-only names keep chronological order == lexicographic
#   order under every locale/collation (a "-2" suffix would not: '-' sorts
#   before '.' in C locale and punctuation is reordered under UTF-8 collation).
# - Count cap: keeps at most HANDOFF_HISTORY_MAX snapshots (default 200),
#   deleting the oldest. Age-based cleanup happens in the SessionStart hook
#   (HANDOFF_HISTORY_RETENTION_DAYS, default 30).

param(
  [string]$File = ".claude/handoff/current.md"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $File)) {
  [Console]::Error.WriteLine("ERROR: file not found: $File")
  exit 1
}

$fileFull = (Resolve-Path $File).Path
$histDir = Join-Path (Split-Path -Parent $fileFull) "history"
New-Item -ItemType Directory -Force -Path $histDir | Out-Null

$t = (Get-Date).ToUniversalTime()
while ($true) {
  $ts = $t.ToString("yyyyMMddTHHmmssZ")
  $dest = Join-Path $histDir "$ts.md"
  if (-not (Test-Path $dest)) { break }
  $t = $t.AddSeconds(1)
}

Copy-Item $fileFull $dest
[Console]::Error.WriteLine("[handoff-revive] snapshot: $dest")

# Count cap: delete oldest beyond HANDOFF_HISTORY_MAX.
$max = 200
if ($env:HANDOFF_HISTORY_MAX -match '^\d+$') { $max = [int]$env:HANDOFF_HISTORY_MAX }
if ($max -gt 0) {
  $files = Get-ChildItem -Path $histDir -Filter "*.md" | Sort-Object Name
  if ($files.Count -gt $max) {
    $files | Select-Object -First ($files.Count - $max) | Remove-Item -Force -ErrorAction SilentlyContinue
  }
}

exit 0

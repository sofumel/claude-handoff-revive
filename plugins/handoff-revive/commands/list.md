---
description: List handoff snapshots in `.claude/handoff/history/` (one is archived automatically on every save).
---

Run the `list-history` script and show the result in the user's language (read `.claude/handoff/lang`):

- Linux/macOS/WSL/Git-Bash:
  ```
  bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/list-history.sh"
  ```
- Windows PowerShell:
  ```
  $r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/list-history.ps1"
  ```

Then remind the user they can restore any snapshot with `/handoff-revive:restore <timestamp>` (the current handoff is archived first, so restore is never destructive).

Note: snapshots older than `HANDOFF_HISTORY_RETENTION_DAYS` (default 30) are cleaned up automatically at session start.

---
description: Restore a handoff snapshot from `.claude/handoff/history/` as the current handoff. Usage - /handoff-revive:restore <timestamp>
argument-hint: <timestamp>
---

Restore the snapshot the user named (`$ARGUMENTS`). If no timestamp was given, run `/handoff-revive:list` behavior first (list-history script) and ask which one to restore.

- Linux/macOS/WSL/Git-Bash:
  ```
  bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/restore-history.sh" <timestamp>
  ```
- Windows PowerShell:
  ```
  $r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/restore-history.ps1" -Timestamp <timestamp>
  ```

The script archives the existing `current.md` into history before overwriting, so nothing is lost. On success, confirm in the user's language and offer to run `/handoff-revive:resume` to continue from the restored snapshot.

Note: this restores the **structured handoff snapshot** (goal / done / wip / todo / next_action / touched_files / decisions / lessons_learned) — not the full conversation. Rolling back conversation history is what native `--resume` / `/rewind` do; this restores the much cheaper work-state checkpoint instead.

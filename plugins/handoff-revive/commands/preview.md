---
description: Preview what the next session will read from `.claude/handoff/current.md` (read-only dry-run, zero-token shell check).
---

Run the `preview-handoff` script and show the result. This is a **read-only** dry-run: it must not modify the handoff.

- Linux/macOS/WSL/Git-Bash:
  ```
  bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/preview-handoff.sh"
  ```
- Windows PowerShell:
  ```
  $r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/preview-handoff.ps1"
  ```

Then, in the user's language (read `.claude/handoff/lang`):

1. Show the summary block (size / token estimate / validation / freshness) as-is.
2. Summarize in 1–2 sentences whether this handoff is good enough to resume from cold: does `next_action` say exactly what to do, and are there warnings to address?
3. If validation is INVALID or freshness warns, suggest `/handoff-revive:save` to refresh — but do not save anything yourself in this command.

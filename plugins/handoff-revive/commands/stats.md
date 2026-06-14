---
description: Show save/resume statistics and the estimated tokens saved vs `claude --resume`.
---

Run the `stats-handoff` script and present the result in the user's language (read `.claude/handoff/lang`):

- Linux/macOS/WSL/Git-Bash:
  ```
  bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/stats-handoff.sh" show
  ```
- Windows PowerShell:
  ```
  $r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/stats-handoff.ps1" -Cmd show
  ```

Keep the ASSUMPTION line intact when relaying the estimate — the savings range is honest guesswork by design, not a measurement. Saves are counted automatically by `finalize-handoff`; resumes are counted during the RESUME flow.

---
description: Park the handoff belonging to another branch and restore this branch's one (per-branch handoffs).
---

Run the `switch-branch-handoff` script and relay its output in the user's language (read `.claude/handoff/lang`):

- Linux/macOS/WSL/Git-Bash:
  ```
  bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/switch-branch-handoff.sh"
  ```
- Windows PowerShell:
  ```
  $r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/switch-branch-handoff.ps1"
  ```

What it does: `current.md` stays the single active handoff; the one belonging to another branch is parked under `.claude/handoff/branches/<branch>.md` and the current branch's parked handoff (if any) is restored. Nothing is destroyed — collisions are archived to history first.

After a successful restore, offer `/handoff-revive:resume`. If it restored nothing (clean slate), suggest `/handoff-revive:save` once work starts. If it errors because the handoff has no `branch:` metadata, explain it predates v1.1 and should be re-saved on its own branch first.

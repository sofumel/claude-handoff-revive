---
description: Show what changed between the current handoff and a past snapshot, section by section. Usage - /handoff-revive:diff [timestamp]
argument-hint: [timestamp]
---

Run the `diff-handoff` script (pass the user's timestamp `$ARGUMENTS` if given; otherwise it compares against the previous save automatically):

- Linux/macOS/WSL/Git-Bash:
  ```
  bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/diff-handoff.sh" [timestamp]
  ```
- Windows PowerShell:
  ```
  $r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/diff-handoff.ps1" [-Timestamp <timestamp>]
  ```

Then, in the user's language (read `.claude/handoff/lang`), present the output and add a 1–2 sentence progress summary: what moved from todo/wip to done, how `next_action` changed, and any new `lessons_learned`. `+` lines were added since the snapshot, `-` lines were removed.

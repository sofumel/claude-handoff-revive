---
description: Diagnose the handoff-revive installation - toolchain, script pairs, hooks, and current handoff state.
---

Run the `doctor-handoff` script and present the result in the user's language (read `.claude/handoff/lang` if present):

- Linux/macOS/WSL/Git-Bash:
  ```
  bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/doctor-handoff.sh"
  ```
- Windows PowerShell:
  ```
  $r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/doctor-handoff.ps1"
  ```

Show the PASS/WARN/INFO lines as-is, then summarize: if there are WARN lines, explain in 1–2 sentences what each one means and the most likely fix (HOOK_SETUP.md for hook wiring, reinstall for missing script pairs, `/handoff-revive:save` then validate for an invalid handoff). If everything passes, say the installation looks healthy.

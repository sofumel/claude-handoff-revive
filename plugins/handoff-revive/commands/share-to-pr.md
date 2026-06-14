---
description: Post the current handoff as a PR comment so reviewers see the work context. Usage - /handoff-revive:share-to-pr [PR number]
argument-hint: [PR number]
---

Share `.claude/handoff/current.md` to a GitHub PR as a comment. **This publishes the handoff content externally — always show the user what will be posted and get an explicit yes before posting.**

Steps:

1. Run the **dry-run** first (pass the user's PR number `$ARGUMENTS` if given; otherwise the script auto-detects the current branch's PR):
   - Linux/macOS/WSL/Git-Bash:
     ```
     bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/share-to-pr.sh" --dry-run [PR]
     ```
   - Windows PowerShell:
     ```
     $r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/share-to-pr.ps1" -DryRun [-Pr <PR>]
     ```
2. Show the user (in their language, read `.claude/handoff/lang`) which PR it will go to and the body preview. **Warn that the handoff may contain absolute paths or other local details** and point out anything that looks sensitive.
3. Only after the user confirms, run the same command **without** `--dry-run` / `-DryRun`.
4. Report the result. If `gh` is missing or no PR exists for the branch, relay the script's error and stop.

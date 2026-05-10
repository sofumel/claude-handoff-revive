---
description: Save a compact handoff checkpoint so a fresh session can resume cheaply (no `--resume`).
argument-hint: [--verify]
---

Invoke the `handoff-revive` skill in **SAVE** mode.

Arguments: `$ARGUMENTS`

If `$ARGUMENTS` contains `--verify`, run SAVE with the self-verification pass (re-read the saved file and rewrite vague fields). Otherwise run SAVE without verification.

Follow the skill's SAVE flow exactly:
1. Detect language (or read `.claude/handoff/lang`)
2. Fill the schema at `.claude/handoff/current.md`
3. `next_action` MUST include `file:line` + exact command/edit
4. Confirm in the user's language and remind: do NOT use `claude --resume` to resume

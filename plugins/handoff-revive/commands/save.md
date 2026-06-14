---
description: Save a compact handoff checkpoint so a fresh session can resume cheaply (no `--resume`).
---

Invoke the `handoff-revive` skill in **SAVE** mode.

Follow the skill's SAVE flow exactly:
1. Detect language (or read `.claude/handoff/lang`)
2. Carry forward still-relevant `goal` / `decisions` / `lessons_learned` from any existing handoff, then fill the schema at `.claude/handoff/current.md`
3. `next_action` MUST include `file:line` + exact command/edit
4. Run `finalize-handoff`, then do the content-quality pass (step 6 of the skill's SAVE flow) — rewrite any vague `goal` / `decisions` / `blockers` / `wip`
5. Confirm in the user's language and remind: do NOT use `claude --resume` to resume

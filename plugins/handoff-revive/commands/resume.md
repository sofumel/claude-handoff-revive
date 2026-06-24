---
description: Resume work from `.claude/handoff/current.md` in this fresh session (skip `--resume`).
---

Invoke the `handoff-revive` skill in **RESUME** mode.

1. Read `.claude/handoff/current.md` (and `.claude/handoff/lang` for output language).
2. Do NOT read prior session transcripts.
3. Run the `resume-receipt` script first (see SKILL.md RESUME step 3) and show the tiny load-boundary receipt before any edits.
4. Run the `check-freshness` script; if it prints warnings, surface them to the user in their language. Warnings inform — they never block the resume. In the same step run `stats-handoff record resume` (zero-token counter for `/handoff-revive:stats`).
5. State the goal and `next_action` back to the user in 1–2 sentences.
6. Ask "Proceed?" before editing anything.
7. After confirmation, execute `next_action`.

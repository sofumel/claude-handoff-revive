---
description: Resume work from `.claude/handoff/current.md` in this fresh session (skip `--resume`).
---

Invoke the `handoff-revive` skill in **RESUME** mode.

1. Read `.claude/handoff/current.md` (and `.claude/handoff/lang` for output language).
2. Do NOT read prior session transcripts.
3. Run the `check-freshness` script (see SKILL.md RESUME step 3); if it prints warnings, surface them to the user in their language. Warnings inform — they never block the resume. In the same step run `stats-handoff record resume` (zero-token counter for `/handoff-revive:stats`).
4. State the goal and `next_action` back to the user in 1–2 sentences.
5. Ask "Proceed?" before editing anything.
6. After confirmation, execute `next_action`.

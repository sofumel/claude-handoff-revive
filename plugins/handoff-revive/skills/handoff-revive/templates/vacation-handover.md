# Template: vacation-handover

For handing work to **another person** across a longer absence (vacation,
leave, team rotation). Use with `/handoff-revive:save --template=vacation-handover`.

Differences from the default schema:

- frontmatter gains `template: "vacation-handover"` (the validator switches to this ruleset)
- one extra **required** section `## handover_notes` — written for a reader who
  cannot ask you anything: contacts, hard deadlines, and fragile areas
- everything else (goal / done / wip / todo / next_action / touched_files /
  decisions / optional blockers & lessons_learned) is identical to the default

Schema:

```markdown
---
schema_version: "1.0"
template: "vacation-handover"
saved_at: {ISO-8601 timestamp}
lang: {ja|en|zh|zh-TW|ko|es|pt|de|fr|tr}
session_summary_tokens_estimated: {rough count}
---

## goal
{1 line: what is being accomplished}

## done
- {completed item}

## wip
- {in-progress item, with precise state}

## todo
- {not yet started}

## blockers
- {blocking question; omit if none}

## next_action
{REQUIRED. file:line + exact command/edit, executable without further thinking.}

## touched_files
- path/to/file.ts -- {one-line reason}

## decisions
- {decision}: {WHY}

## handover_notes
- contact: {who to ask when blocked, and for what}
- deadline: {hard dates that land during the absence, and what must happen}
- watch_out: {fragile areas, things that look safe but aren't, do-not-touch}

## lessons_learned
- attempted: {tried approach}
  why_abandoned: {why dropped}
  learned: {takeaway}
```

# Hook setup

The handoff-revive skill ships **four** optional hooks. None of them silently invokes a save without surfacing it to the user — auto-save fires only via Claude (with explicit notice in the chat).

## What each hook does

### Stop hook — turn-count nudge

Claude has no introspection of its own token count, so true threshold-based auto-save is impossible from inside a skill. Turn count is a useful proxy. The Stop hook increments `.claude/handoff/.turn` after each turn and prints a stderr reminder every N turns:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff to save.
```

Default threshold: 15 turns. Override with `HANDOFF_CHECKPOINT_EVERY=10` (any positive integer).

### SessionStart hook — `--resume` deflection + session bookkeeping

When a fresh session starts:
1. Captures `session_id` to `.claude/handoff/.session-id` (used by `/handoff-auto` and other hooks)
2. Cleans up orphaned per-session toggle files (>30 days old)
3. Clears stale `.usage-flag` / `.last-warned` from prior sessions
4. If a recent (≤7d old) handoff file exists, injects guidance telling Claude to prefer it over `--resume`

This is what enables the cheap-resume flow when you start a new session after a rate limit.

### PostToolUse hook — usage-rate monitor (NEW)

After each Claude tool call, reads `rate_limits.five_hour.used_percentage` from the hook input JSON. When usage crosses a threshold (and hasn't already this session):

| Crossing | Action |
|---|---|
| `HANDOFF_AUTO_SAVE_PERCENT` (default 90) | Writes `AUTO_SAVE:<percent>` to `.claude/handoff/.usage-flag` |
| `HANDOFF_URGENT_PERCENT` (default 95) | Writes `URGENT:<percent>` (overrides AUTO_SAVE if both crossed) |

Suppression:
- Already-warned bands don't re-fire (tracked in `.claude/handoff/.last-warned`)
- Per-session disable via `.claude/handoff/sessions/<session_id>.disabled` (toggled by `/handoff-auto off`)
- `HANDOFF_AUTO_SAVE_PERCENT=disabled` and `HANDOFF_URGENT_PERCENT=disabled` skip everything

When usage drops back below 50%, the warned-state is cleared (handles 5-hour window resets).

### UserPromptSubmit hook — auto-save dispatcher (NEW)

When the user sends any message, this hook reads `.usage-flag`. If a flag exists (set by PostToolUse), it injects `additionalContext` instructing Claude to **auto-save before responding**. The flag is one-shot: removed after read.

Claude's behavior on receiving the injected context is documented in `skills/handoff-revive/SKILL.md` (Mode 1c: AUTO-SAVE).

## How to enable

### Plugin install: automatic

If you installed via `/plugin install handoff-revive@handoff-revive-marketplace`, all four hooks are activated automatically — Claude Code reads `<plugin-root>/hooks/hooks.json` at install time and registers them. **No `settings.json` editing required.**

### Standalone install: merge the snippet below

If you used `install.sh` / `install.ps1`, merge the appropriate JSON below into your `.claude/settings.json` (project-level) or `~/.claude/settings.json` (global).

#### Linux / macOS / WSL / Git-Bash

```json
{
  "hooks": {
    "Stop": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "bash .claude/hooks/checkpoint-counter.sh" }
      ] }
    ],
    "SessionStart": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "bash .claude/hooks/session-start.sh" }
      ] }
    ],
    "PostToolUse": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "bash .claude/hooks/usage-monitor.sh" }
      ] }
    ],
    "UserPromptSubmit": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "bash .claude/hooks/user-prompt-submit.sh" }
      ] }
    ]
  }
}
```

#### Windows (pure PowerShell, no bash available)

```json
{
  "hooks": {
    "Stop": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/checkpoint-counter.ps1" }
      ] }
    ],
    "SessionStart": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/session-start.ps1" }
      ] }
    ],
    "PostToolUse": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/usage-monitor.ps1" }
      ] }
    ],
    "UserPromptSubmit": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/user-prompt-submit.ps1" }
      ] }
    ]
  }
}
```

`-ExecutionPolicy Bypass` is required on Windows where script execution is blocked by default.

## Per-session opt-out

Inside any Claude session, run:

```
/handoff-auto off       # disable auto-save for THIS session
/handoff-auto on        # re-enable
/handoff-auto status    # show current state + thresholds
/handoff-auto           # same as status
```

This writes/removes `.claude/handoff/sessions/<session_id>.disabled`. Other sessions and new sessions are unaffected (default = enabled).

## Customizing thresholds

| Variable | Default | Effect |
|---|---|---|
| `HANDOFF_CHECKPOINT_EVERY` | 15 | Stop-hook nudge frequency (in turns) |
| `HANDOFF_AUTO_SAVE_PERCENT` | 90 | Usage % to trigger auto-save (`disabled` to skip) |
| `HANDOFF_URGENT_PERCENT` | 95 | Usage % to trigger urgent auto-save (`disabled` to skip) |

Set in `.bashrc` / `.zshrc` / Windows env vars, or per-hook in `settings.json`:

```json
{
  "type": "command",
  "command": "HANDOFF_AUTO_SAVE_PERCENT=85 bash .claude/hooks/usage-monitor.sh"
}
```

To **completely disable auto-save globally** (still allow manual `/handoff`):

```bash
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

To go the other direction (more aggressive):

```bash
export HANDOFF_AUTO_SAVE_PERCENT=80   # earlier auto-save
export HANDOFF_URGENT_PERCENT=90      # earlier urgent
```

## Disabling without uninstalling

- Plugin install: `/plugin disable handoff-revive` removes all hooks at once
- Standalone install: remove the relevant entries from `settings.json`
- Auto-save only: set the env vars above to `disabled`
- Per-session opt-out: `/handoff-auto off`

## State files reference

```
.claude/handoff/
├── current.md                          # the handoff itself
├── lang                                # language code (ja|en|zh|ko|es)
├── .turn                               # turn counter (Stop hook); RESET by SessionStart hook
├── .session-id                         # current session id (SessionStart hook)
├── .usage-flag                         # one-shot auto-save directive (PostToolUse → UserPromptSubmit, atomically claimed)
├── .last-warned                        # last threshold band fired (90 or 95); RESET by SessionStart and on usage<50%
└── sessions/
    └── <session_id>.disabled           # per-session auto-save opt-out (orphans >30d auto-cleaned by SessionStart)
```

**Lifecycle invariants:**
- `.turn` resets at SessionStart so the nudge fires at turn 15 of each session, not turn 15 of accumulated history across sessions
- `.usage-flag` is consumed atomically (renamed to `.usage-flag.claimed.<pid>` before read) so concurrent UserPromptSubmit hooks can't lose a flag
- `.last-warned` is written *before* `.usage-flag` so consumers always see consistent state
- `sessions/<id>.disabled` files older than 30 days are auto-removed at SessionStart

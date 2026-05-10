# Changelog

All notable changes to `claude-handoff-revive` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-05-10

Initial public release.

### Features

- **Compact handoff schema** — `goal / done / wip / todo / next_action / touched_files / decisions` saved to `.claude/handoff/current.md` (~1–3k tokens vs `claude --resume`'s 30k–200k)
- **Slash commands** — `/handoff`, `/handoff --verify`, `/resume-from-handoff`, `/handoff-auto on|off|status`
- **Four hooks** —
  - `Stop` (turn-count nudge every N turns, configurable via `HANDOFF_CHECKPOINT_EVERY`)
  - `SessionStart` (`--resume` deflection + state cleanup + session-id capture)
  - `PostToolUse` (`usage-monitor`: reads `rate_limits.five_hour.used_percentage`, fires at 90% / 95%)
  - `UserPromptSubmit` (auto-save dispatcher, atomic flag claim)
- **Auto-save at 90% / 95% usage** — synced with Claude Code's UI notification, per-session toggleable via `/handoff-auto off`, globally disable-able with `HANDOFF_AUTO_SAVE_PERCENT=disabled HANDOFF_URGENT_PERCENT=disabled`
- **Deterministic shell scripts** — `validate-handoff`, `extract-recent-files`, `cleanup-handoff`, `finalize-handoff` all run with zero LLM tokens (pure bash + PowerShell)
- **10-language support** — `en`, `ja`, `zh`, `zh-TW`, `ko`, `es`, `pt`, `de`, `fr`, `tr` with auto-detection from the user's message and persistence across sessions
- **Cross-platform parity** — every script and hook ships in both bash and PowerShell variants, tested on Ubuntu / macOS / Windows in CI
- **Two install paths** — plugin install via `/plugin marketplace add … && /plugin install …`, or standalone `install.sh` / `install.ps1` for environments without plugin support
- **Security defenses** — session-id whitelist (`^[A-Za-z0-9_-]+$`), shell-injection-safe `touched_files` cleanup, ASCII-only hook stdout to avoid encoding issues
- **MIT licensed**

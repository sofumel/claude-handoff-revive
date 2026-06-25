# Changelog

All notable changes to `claude-handoff-revive` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] — 2026-06-25

### Added

- **Resume receipt** — `/handoff-revive:resume` now prints a tiny load-boundary receipt before any edits: handoff path, saved/current branch, base commit, the sections present, `next_action` presence, freshness summary, and privacy flags — without echoing the handoff body or the prior transcript. Thanks @caioribeiroclw-pixel ([#2](https://github.com/sofumel/claude-handoff-revive/pull/2)).
- `CONTRIBUTING.md` — contributor guide (bash/PowerShell parity, lint gates, line-ending/BOM rules, how to run the test suites), linked from the README header.

### Fixed

- **Secret detection was silently disabled on CRLF checkouts.** `sanitize-handoff.sh` read `lib/secret-patterns.txt` line-by-line without stripping a trailing `\r`, so a Windows clone with `autocrlf=true` checked the file out as CRLF and every known-prefix pattern gained a trailing carriage return — the alternation stopped matching and `share-to-pr` would **not** abort on a real API key. Now strips the CR per pattern, and `.gitattributes` pins `*.txt` to LF. The PowerShell twin was unaffected (`Get-Content` + `.Trim()` already drop the CR). Added `test-sanitize-crlf.{sh,ps1}` regression tests.

## [2.0.0] — 2026-06-14

Initial public release of the rebuilt plugin. Everything below runs as pure
shell (zero LLM tokens) on both bash and PowerShell, covered by 24 local
tests per platform and 3-OS CI (Ubuntu / macOS / Windows).

### Core

- **Compact handoff schema** — `goal / done / wip / todo / next_action / touched_files / decisions` (plus optional `blockers`, `lessons_learned`) saved to `.claude/handoff/current.md` (~1–3k tokens vs `claude --resume`'s tens of thousands, often 100k+ for long sessions)
- **Schema as a contract** — `schema_version: "1.0"` with a documented compatibility matrix (missing = legacy 1.0, 1.x accepted, future majors rejected)
- **Carry-forward saves** — each save first reads the existing handoff and carries still-relevant goal / decisions / lessons_learned forward, then runs a content-quality pass — on **every** save, including auto-save
- **Resume from a new session** — `/handoff-revive:resume` reads only that one small file; no transcript replay

### Slash commands (11)

- `save`, `resume`, `preview`, `list`, `restore`, `diff`, `share-to-pr`, `stats`, `doctor`, `switch`, `auto`

### Hooks (5, auto-activated on plugin install)

- `Stop` — per-turn markers; optional turn-count nudge, **off by default** (enable via `HANDOFF_CHECKPOINT_EVERY`)
- `SessionStart` — surfaces a recent handoff (window via `HANDOFF_SURFACE_DAYS`, default 7), `--resume` deflection, state cleanup, unsaved-exit detection, branch-mismatch notice
- `PostToolUse` (`usage-monitor`) — reads `rate_limits.five_hour.used_percentage`; flags auto-save at 90% / 95%
- `UserPromptSubmit` — auto-save dispatcher (atomic one-shot flag claim)
- `PreCompact` — gate that blocks a manual `/compact` when there is unsaved work (auto-compaction is never blocked; `HANDOFF_COMPACT_GATE=off` disables)

### Automatic, zero-token

- **Auto-save at 90% / 95% usage** — on by default, synced with Claude Code's UI notification; per-session toggle via `/handoff-revive:auto off`, permanent off via `HANDOFF_AUTO_SAVE_PERCENT=disabled HANDOFF_URGENT_PERCENT=disabled`
- **Auto-injected sharing metadata** — `author`, `branch`, `base_commit`, `created_at` written into the frontmatter on every save (YAML-escape-safe; `HANDOFF_HIDE_EMAIL=1` to omit the email)
- **Reference integrity** — every `touched_files` path and `next_action` file:line is existence-checked; `planned:` marker bypasses the check for not-yet-created files
- **Snapshot history** — every save archives to `.claude/handoff/history/<timestamp>.md`; `/handoff-revive:list`, `/handoff-revive:restore <ts>` (non-destructive), `/handoff-revive:diff [ts]` (section-wise +/− vs the previous save); retention via `HANDOFF_HISTORY_RETENTION_DAYS` (30) and `HANDOFF_HISTORY_MAX` (200)
- **Freshness checks on resume** — warns when the handoff is N commits behind, on another branch, or older than `HANDOFF_STALE_DAYS` (7; the age check works without git). Purely informational — never blocks the resume

### Sharing & portability

- **Team sharing** — `/handoff-revive:share-to-pr [PR]` posts the handoff as a PR comment via `gh` (dry-run first, explicit confirmation, 60k size guard)
- **Sanitization (best-effort, never a guarantee)** — the shared body is built from a copy with `author_email` removed, project/home paths replaced by `<project-root>` / `~`, and known-prefix secrets (`sk-`, `ghp_`, `AKIA`, private-key blocks, JWTs …) detected — detection aborts the share, nothing is ever silently redacted
- **Per-branch handoffs** — `/handoff-revive:switch` parks the other branch's `current.md` under `branches/<slug>.md` and restores the current branch's one, never destructively
- **`vacation-handover` template** — a longer-leave variant with its own required `handover_notes` section

### Docs, i18n, infrastructure

- **10-language README** — `en / ja / zh / zh-TW / ko / es / pt / de / fr / tr`, full structural parity across every section, with a CI guard that each command row appears once per language; language auto-detected from the user's message and persisted across sessions
- **CLAUDE.md role separation** — documented, with an opt-in `setup-claude-md` helper; `SKILL.ja.md` Japanese reference translation
- **Cross-platform parity** — every script and hook ships in both bash and PowerShell variants; 24 local tests per platform wired into 3-OS CI
- **Two install paths** — plugin marketplace install (`/plugin marketplace add … && /plugin install …`), or standalone `install.sh` / `install.ps1` for environments without plugin support

### License

- MIT

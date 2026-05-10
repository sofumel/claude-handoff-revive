---
name: handoff-revive
description: Save a compact handoff checkpoint and resume work in a fresh session without replaying the entire transcript via `--resume`. SAVE trigger — the slash command `/handoff` (with optional `--verify` argument). AUTO-SAVE trigger — when the UserPromptSubmit hook injects "5-hour usage at N%" context (run SAVE flow without asking, prepend brief notice). RESUME trigger — the slash command `/resume-from-handoff`. Also use when the SessionStart hook surfaces an existing handoff at `.claude/handoff/current.md` — read that file instead of recommending `claude --resume`. Configuration via `/handoff-auto on|off|status` (per-session toggle). Do NOT trigger on natural-language phrases like "save handoff" / "ハンドオフ保存して" / "続きから" — only the slash commands and hook contexts above.
---

# handoff-revive

Save the minimum state needed to continue work later, so the next session can start fresh (NOT via `--resume` / `-c`) and reload only a small file.

## Why not `claude --resume`

`--resume` and `-c` replay the entire prior transcript into context. For a typical session this costs **30,000–200,000 tokens** before the user even asks anything. A handoff file costs **1,000–3,000 tokens**. Always prefer the handoff file when one exists.

## Two modes

### Mode 1: SAVE (`/handoff`)

Triggered ONLY by:
- User runs the slash command `/handoff` (or `/handoff --verify`)
- The UserPromptSubmit hook injects auto-save context (see Mode 1c below)

Do **NOT** trigger on natural-language phrases like "save handoff", "checkpoint", "ハンドオフ", "保存", "保存して中断". Users are expected to use the slash command. If a user types one of those phrases without the slash command, treat it as a regular message (gently remind them they can run `/handoff` if they want to save).

Steps:

1. **Detect language** — read `.claude/handoff/lang` if it exists. Trim whitespace; the file holds a language code (one of: `ja`, `en`, `zh` (Simplified), `zh-TW` (Traditional), `ko`, `es`, `pt`, `de`, `fr`, `tr`) with no trailing newline. Otherwise detect from the user's most recent message:

   - Hiragana/Katakana → `ja`
   - Hangul → `ko`
   - Han characters: simplified markers (e.g. 这, 国, 学) → `zh`; traditional markers (e.g. 這, 國, 學) → `zh-TW`
   - Cyrillic / Arabic → fall back to `en`
   - Latin script: detect by common diacritics + words:
     - `é à è ç` + words like *fichier*, *avec*, *est* → `fr`
     - `ä ö ü ß` + words like *Datei*, *und*, *ist* → `de`
     - `ã õ ç` + words like *arquivo*, *está*, *para* → `pt`
     - `ñ` + Spanish words (*archivo*, *está*, *con*) → `es`
     - `ı ş ğ ç` + Turkish words (*dosya*, *için*, *çalış*) → `tr`
     - Otherwise → `en`

   When the message is mixed or ambiguous, default to `en`. Write the chosen code to `.claude/handoff/lang` (no newline) using your file-write tool. Subsequent saves reuse the persisted value unless the user explicitly asks to switch language.

2. **Fill the schema** — write to `.claude/handoff/current.md` using the template below. All section keys stay in English (machine-readable); section *values* go in the user's language.

3. **For `next_action`: be executable.** Not "continue refactoring auth" but `Edit src/auth/login.ts:42 — replace the bcrypt.compare call with the timing-safe variant from line 88`. Include the exact file:line and the exact next command/edit. The goal is zero "thinking time" on resume.

4. **For `touched_files`: format as `path -- one-line reason`.** Use ` -- ` (space, two dashes, space) as the separator, NOT `:`, because Windows absolute paths contain a colon (`C:\...`) and would break the schema. Always prefer **project-relative paths with forward slashes** (`src/auth/login.ts`); fall back to absolute paths only when the file is genuinely outside the project. No diffs, no line ranges — just enough to re-orient.

   **Token-saving helper (recommended)**: instead of thinking through which files to list, run `extract-recent-files` to get a deterministic list from `git status` (or `find -mmin` if non-git). This saves ~200–500 tokens per save:
   - Linux/macOS/WSL/Git-Bash: `bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/extract-recent-files.sh"`
   - Windows PowerShell: `$r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/extract-recent-files.ps1"`

   The script outputs `- <path> -- <reason>` lines (max 20). Paste them under `## touched_files`, then refine reasons where the auto-generated `modified` / `untracked` doesn't capture intent (e.g. "needs rollback" / "validated; do not touch").

5. **Run `finalize-handoff`** — single zero-token call that does validate + cleanup + savings report. Path uses `${CLAUDE_PLUGIN_ROOT:-.claude}` so the same command works in plugin and standalone installs:
   - Linux/macOS/WSL/Git-Bash:
     ```
     bash "${CLAUDE_PLUGIN_ROOT:-.claude}/skills/handoff-revive/scripts/finalize-handoff.sh"
     ```
   - Windows PowerShell:
     ```
     $r = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { ".claude" }; powershell -ExecutionPolicy Bypass -File "$r/skills/handoff-revive/scripts/finalize-handoff.ps1"
     ```

   - **Exit 0**: handoff is valid and finalized. Stderr will show `[handoff-revive] OK Saved <path> (~N tokens). Estimated savings on next resume: ~30,000–200,000 tokens (vs --resume…).` Capture both lines and surface them to the user in step 7.
   - **Exit 1**: validator failed. Stderr lists the issues. Read each, fix the corresponding fields in `.claude/handoff/current.md`, then re-call. **Maximum 2 retries** — if still failing, stop and warn the user with remaining errors.

   If the user explicitly sets `HANDOFF_SKIP_VALIDATE=1`, skip this step.

6. **Optional Claude self-verification (`/handoff --verify` only).** `finalize-handoff` catches structural issues for free. `--verify` mode adds a Claude-driven semantic-quality pass: is `goal` specific enough? does each `decision` include a real *reason*? are blockers phrased as answerable questions? Rewrite vague fields and re-run finalize.

7. **Confirm to user in their language.** State the path saved, summarize `next_action` in 1 line, **show the savings line** from finalize's stderr (e.g. "節約見込み: ~30,000–200,000 tokens"), and remind: **"To resume, start a NEW session (do not use `claude --resume`) and run `/resume-from-handoff`."**

### Mode 1b: SAVE with content-quality verification (`/handoff --verify`)

The deterministic validator (folded into `finalize-handoff`) handles all *structural* issues for free. The `--verify` mode adds an extra Claude-driven *content-quality* pass that the validator cannot do:

- Is `goal` specific enough that someone with no context understands it? (Validator only checks non-empty.)
- Does each entry in `decisions` include a real *reason* after the dash, not just the decision restated?
- Are `blockers` phrased as answerable questions, not vague worries?
- Does `wip` describe state precisely enough to resume mid-edit (e.g. "1/3 functions converted, line 42 next" — not "still working on auth")?

If any of the above is weak, rewrite that field and save again. Validator re-runs automatically. Then confirm to user.

### Mode 1c: AUTO-SAVE (triggered by hook, no user request)

Auto-save fires when the **UserPromptSubmit hook injects `additionalContext`** containing one of the directives below. The hook fires after the `usage-monitor` PostToolUse hook detected `rate_limits.five_hour.used_percentage` crossing a configured threshold (defaults: 90% / 95%).

**You will see context like one of these in the user's prompt:**

```
⚠️ 5-hour usage at 92%. Auto-save a handoff before answering the user. Run the SAVE flow (extract-recent-files → write handoff → finalize-handoff). Do NOT ask the user. After save, briefly notify them in their language…
```

```
🚨 CRITICAL: 5-hour usage at 96%. IMMEDIATELY auto-save a handoff before answering the user…
```

**When you see this:**

1. **Do NOT ask permission.** The user has implicitly opted in by leaving auto-save enabled (default). If they wanted to ask first, they would have run `/handoff-auto off`.

2. **Run the full SAVE flow** (steps 1–5 of Mode 1: detect lang → fill schema → executable next_action → fill touched_files → finalize-handoff). Use `extract-recent-files` to populate `touched_files` and `finalize-handoff` for validate + cleanup + savings.

3. **Prepend a brief auto-save notice** to your response in the user's language, then handle their actual request. Examples:

   | lang | AUTO_SAVE notice (e.g. 92%) | URGENT notice (e.g. 96%) |
   |---|---|---|
   | ja | ⚠️ 使用量 92% に到達したため、ハンドオフを自動保存しました (~N tokens)。 | 🚨 緊急: 使用量 96%、自動保存しました (~N tokens)。新規セッションで `/resume-from-handoff` を実行すれば再開できます。 |
   | en | ⚠️ Usage hit 92% — auto-saved handoff (~N tokens). | 🚨 CRITICAL: usage at 96% — auto-saved (~N tokens). Start a new session and run `/resume-from-handoff` if rate-limited. |
   | zh | ⚠️ 使用率达到 92%，已自动保存交接 (~N tokens)。 | 🚨 紧急: 使用率 96%，已自动保存。新会话运行 `/resume-from-handoff` 即可恢复。 |
   | zh-TW | ⚠️ 使用率達到 92%，已自動儲存交接 (~N tokens)。 | 🚨 緊急: 使用率 96%，已自動儲存。新會話執行 `/resume-from-handoff` 即可恢復。 |
   | ko | ⚠️ 사용량 92% 도달, 핸드오프 자동 저장 (~N tokens). | 🚨 긴급: 사용량 96%, 자동 저장. 새 세션에서 `/resume-from-handoff` 실행. |
   | es | ⚠️ Uso al 92% — handoff auto-guardado (~N tokens). | 🚨 CRÍTICO: uso al 96% — auto-guardado. Inicia sesión nueva y ejecuta `/resume-from-handoff`. |
   | pt | ⚠️ Uso a 92% — handoff auto-guardado (~N tokens). | 🚨 CRÍTICO: uso a 96% — auto-guardado. Inicia uma sessão nova e executa `/resume-from-handoff`. |
   | de | ⚠️ Nutzung bei 92% — Handoff automatisch gespeichert (~N tokens). | 🚨 KRITISCH: Nutzung bei 96% — automatisch gespeichert. Starte neue Sitzung und führe `/resume-from-handoff` aus. |
   | fr | ⚠️ Utilisation à 92% — handoff auto-sauvegardé (~N tokens). | 🚨 CRITIQUE : utilisation à 96% — auto-sauvegardé. Lancez une nouvelle session et exécutez `/resume-from-handoff`. |
   | tr | ⚠️ Kullanım %92 — handoff otomatik kaydedildi (~N tokens). | 🚨 KRİTİK: kullanım %96 — otomatik kaydedildi. Yeni oturum başlatın ve `/resume-from-handoff` çalıştırın. |

4. **Add a separator (`────────`) and continue with the user's actual request** — do not let the auto-save interrupt the work.

5. **If `finalize-handoff` fails after 2 retries**, warn the user briefly but proceed with their request anyway. Their work is more important than a clean handoff at this moment.

### Mode 2: RESUME (new session, after limit reset)

Triggered ONLY by:
- User runs the slash command `/resume-from-handoff`
- The SessionStart hook injected `additionalContext` mentioning the existing `.claude/handoff/current.md` AND the user then runs `/resume-from-handoff` (the hook only surfaces files modified within the last 7 days; older files are treated as stale)

Do **NOT** trigger on natural-language phrases like "resume from handoff", "continue", "続きから", "继续", "계속", "reanudar". Users are expected to use the slash command. If you see one of those phrases without the slash command, gently remind the user they can run `/resume-from-handoff`.

Note: skills cannot intercept the `claude --resume` / `-c` CLI flag (the flag is processed before the skill loads). The SessionStart hook is what differentiates a `--resume` session from a fresh start; if the user is in a `--resume` session and a handoff exists, you may briefly note that `/resume-from-handoff` in a new session would have been cheaper, but proceed with their `--resume` flow.

Steps:

1. Read `.claude/handoff/current.md`. **Do not read prior session transcripts.**
2. Read `.claude/handoff/lang` and respond in that language.
3. Read each file listed in `touched_files` only if needed for the immediate `next_action`. Do not preemptively read all of them.
4. State the goal and `next_action` back to the user in 1–2 sentences and ask "Proceed?" before editing.
5. After the user confirms or redirects, execute `next_action`.

## Schema (template)

Write to `.claude/handoff/current.md`:

```markdown
---
saved_at: {ISO-8601 timestamp}
lang: {ja|en|zh|zh-TW|ko|es|pt|de|fr|tr}
session_summary_tokens_estimated: {rough count}
---

## goal
{1 line: what is the user ultimately trying to accomplish}

## done
- {completed item}
- ...

## wip
- {currently in-progress item, with state}

## todo
- {not yet started}
- ...

## blockers
- {question or unknown that is blocking; omit section if none}

## next_action
{REQUIRED. file:line + exact command/edit. Must be executable without further thinking.}

## touched_files
- path/to/file.ts -- {one-line reason}
- ...

## decisions
- {decision}: {WHY — the reason behind it, not just what was decided}
- ...
```

Section headings use H2 (`##`) so the file renders cleanly on GitHub / VS Code preview while remaining unambiguous to parse.

## Hook setup

Plugin installs auto-activate hooks. Standalone installs need a `settings.json` snippet — see `HOOK_SETUP.md` at the repo root for the snippets and full details.

## Multi-language

Confirmation messages and the `next_action` summary line are written in the user's language. Section *keys* (`goal`, `done`, etc.) stay in English so the schema is parseable across languages. Supported: `ja`, `en`, `zh` (Simplified), `zh-TW` (Traditional), `ko`, `es`, `pt`, `de`, `fr`, `tr`. For other languages, fall back to English keys + the user's language for values.

Example confirmation strings:

| lang | save confirmation |
|---|---|
| ja | ハンドオフ保存しました: `.claude/handoff/current.md`。再開時は**新規セッション**で `/resume-from-handoff` を実行してください（`claude --resume` は使わない）。 |
| en | Handoff saved: `.claude/handoff/current.md`. To resume, start a **new session** and run `/resume-from-handoff` (do NOT use `claude --resume`). |
| zh | 已保存交接文件: `.claude/handoff/current.md`。恢复时请**新建会话**并运行 `/resume-from-handoff`（不要使用 `claude --resume`）。 |
| ko | 핸드오프 저장됨: `.claude/handoff/current.md`. 재개 시 **새 세션**에서 `/resume-from-handoff` 를 실행하세요 (`claude --resume` 사용 금지). |
| es | Handoff guardado: `.claude/handoff/current.md`. Para reanudar, inicia una **sesión nueva** y ejecuta `/resume-from-handoff` (NO uses `claude --resume`). |

## Token budget

Net cost per save: ~300–1,400 tokens (incl. `finalize-handoff` overhead).
Net cost per resume: ~800–2,800 tokens.
Net cost per AUTO-SAVE event: ~500–1,500 tokens (one full save per threshold crossing, max 2 per session: AUTO_SAVE then URGENT).
`claude --resume` costs 30k–200k tokens for the same resumption.

**Break-even: 1 resume per save.** Saves only, never resume → only the SKILL.md load is wasted. Best case: 50–100× cheaper than `--resume`.

`finalize-handoff` outputs `Estimated savings on next resume: ~30,000–200,000 tokens` to stderr after each save. Surface that line to the user in the confirmation message.

Auto-save can be opted out per-session via `/handoff-auto off`, or globally via `HANDOFF_AUTO_SAVE_PERCENT=disabled` and `HANDOFF_URGENT_PERCENT=disabled`.

## Do NOT

- Do not read prior session transcripts on resume. The handoff file is the single source of truth.
- Do not silently auto-invoke save from a hook (burns tokens without user knowing). Hooks only *nudge*.
- Do not write the entire conversation into the handoff file. Only the schema fields.
- Do not use `--resume` / `-c` if a current handoff file exists. Warn the user first.
- Do not translate section keys. Keys stay in English; values go in user's language.

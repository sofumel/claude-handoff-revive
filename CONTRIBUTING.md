# Contributing

Thanks! Bug fixes, docs, translations, and features are all welcome.

**Philosophy**

- Deterministic work runs in **pure shell** — zero LLM tokens, no `jq`/`python`/`node`.
- Every script and hook ships in **both** Bash (`.sh`) and PowerShell (`.ps1`). Change one, change its twin.
- Best-effort safety (e.g. secret detection) must **fail loudly, never silently redact**.

**Before you start** — small fixes: just open a PR. Behavior changes or new features: open an issue first.

## Tests

No build step; you need `bash` (Git-Bash on Windows is fine) and PowerShell.

```sh
bash plugins/handoff-revive/skills/handoff-revive/scripts/tests/run-tests.sh      # add a name to run one
pwsh plugins/handoff-revive/skills/handoff-revive/scripts/tests/run-tests.ps1
```

Add a `test-<thing>.sh` / `.ps1` for any behavior change (the harness auto-discovers `test-*`).

## Rules CI enforces (green on Ubuntu / macOS / Windows)

- **Line endings:** `.sh` = LF · `.ps1` = CRLF + UTF-8 **BOM** · `.txt`/`.md`/`.json`/`.yml` = LF (pinned in `.gitattributes`).
- **Lint:** `shellcheck -S warning` clean; PSScriptAnalyzer clean at Error+Warning (approved verbs, singular nouns).
- **Parity:** change a script/hook → update both `.sh` and `.ps1`, and ship it in both `install.sh` and `install.ps1`.
- **README i18n:** the command table exists in 10 languages — command strings identical across all, only the description translated.
- **Schema:** handoff section keys stay English; values are in the user's language.

## Pull requests

Keep them small and focused. Say **what** and **why**, note the platforms you tested, and confirm `git diff --check` is clean.

By contributing you agree your work is licensed under the project's [MIT License](LICENSE).

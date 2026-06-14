---
description: Toggle automatic handoff save (90%/95% triggers) for THIS session — pass on, off, or status
argument-hint: on | off | status
---

Toggle the per-session auto-save switch. Auto-save is **enabled by default**; this command lets the user opt out (or back in) for the current session only — new sessions reset to default.

Argument: `$ARGUMENTS` (one of: `on`, `off`, `status`, or empty for `status`)

## How to handle

1. **Resolve and validate the session id.** Use the Bash tool (Linux/macOS/WSL/Git-Bash) OR the PowerShell tool (Windows-only environments) to read and validate `.claude/handoff/.session-id`. Pick whichever shell is available in this environment.

   **Bash variant:**
   ```sh
   SID=$(cat .claude/handoff/.session-id 2>/dev/null || true)
   # Whitelist: only alphanumerics, dashes, and underscores. Defends against
   # path traversal (../) or shell metacharacters in case .session-id was
   # tampered with. Real Claude Code session_ids are UUIDs; this matches them.
   if [ -z "$SID" ] || ! printf '%s' "$SID" | grep -qE '^[A-Za-z0-9_-]+$'; then
     echo "ERROR: session id missing or invalid"
     exit 1
   fi
   echo "$SID"
   ```

   **PowerShell variant:**
   ```powershell
   $sid = (Get-Content .claude/handoff/.session-id -Raw -ErrorAction SilentlyContinue)
   if ($sid) { $sid = $sid.Trim().TrimStart([char]0xFEFF) }
   # Same whitelist as the bash variant — defense in depth.
   if (-not $sid -or $sid -notmatch '^[A-Za-z0-9_-]+$') {
     Write-Output "ERROR: session id missing or invalid"
     exit 1
   }
   Write-Output $sid
   ```

   If the command exits non-zero (empty or invalid), tell the user in their language:
   - "Session ID not yet captured. Make sure the SessionStart hook is enabled (see HOOK_SETUP.md). Try again after one Claude turn."
   - And stop. Do NOT proceed to step 2.

2. **Resolve the action** based on `$ARGUMENTS`:

   - **`on`** — Re-enable auto-save for this session:
     ```sh
     rm -f ".claude/handoff/sessions/${SID}.disabled" && echo "ENABLED"
     ```
     PowerShell: `Remove-Item ".claude/handoff/sessions/$sid.disabled" -Force -ErrorAction SilentlyContinue; Write-Output "ENABLED"`

     Confirm to user in their language (e.g. ja: 「✓ このセッションでの自動保存を有効にしました。90% / 95% で自動保存が走ります。」)

   - **`off`** — Disable auto-save for this session only:
     ```sh
     mkdir -p .claude/handoff/sessions && touch ".claude/handoff/sessions/${SID}.disabled" && echo "DISABLED"
     ```
     PowerShell:
     ```powershell
     New-Item -ItemType Directory -Force -Path .claude/handoff/sessions | Out-Null
     New-Item -ItemType File -Force -Path ".claude/handoff/sessions/$sid.disabled" | Out-Null
     Write-Output "DISABLED"
     ```

     Confirm: "✓ Auto-save disabled for this session. Use `/handoff-revive:save` to save manually whenever you want. New Claude sessions reset to enabled."

   - **`status`** (or empty) — Report current state:
     ```sh
     if [ -f ".claude/handoff/sessions/${SID}.disabled" ]; then
       echo "DISABLED"
     else
       echo "ENABLED"
     fi
     ```
     PowerShell: `if (Test-Path ".claude/handoff/sessions/$sid.disabled") { "DISABLED" } else { "ENABLED" }`
     Then report to user:
     - State: ENABLED / DISABLED
     - Effective thresholds (read env vars `HANDOFF_AUTO_SAVE_PERCENT`, `HANDOFF_URGENT_PERCENT`; defaults 90 / 95)
     - Reminder: "New Claude sessions start ENABLED by default."
     - If both env vars are `disabled`, mention that auto-save is also globally disabled regardless of session toggle.

   - Anything else: tell the user usage is `/handoff-revive:auto on | off | status`.

3. **Always respond in the user's language** (read `.claude/handoff/lang` if it exists, otherwise detect from the user's message). Confirmation patterns:
   - ja: 「✓ このセッションでの自動保存を{有効|無効}にしました。」
   - en: "✓ Auto-save {enabled|disabled} for this session."
   - zh: "✓ 已为本会话{启用|禁用}自动保存。"
   - zh-TW: 「✓ 已為本會話{啟用|停用}自動儲存。」
   - ko: "✓ 이 세션에서 자동 저장 {활성화|비활성화}."
   - es: "✓ Auto-guardado {activado|desactivado} para esta sesión."
   - pt: "✓ Auto-save {ativado|desativado} para esta sessão."
   - de: "✓ Auto-Save für diese Sitzung {aktiviert|deaktiviert}."
   - fr: "✓ Auto-sauvegarde {activée|désactivée} pour cette session."
   - tr: "✓ Bu oturum için otomatik kayıt {etkinleştirildi|devre dışı bırakıldı}."

## Notes

- The toggle is **per-session** (scoped by session_id). Other concurrent sessions are unaffected.
- New Claude sessions start in the default state (enabled). To make disable persistent across sessions, set the env vars `HANDOFF_AUTO_SAVE_PERCENT=disabled` and `HANDOFF_URGENT_PERCENT=disabled`.
- Manual `/handoff-revive:save` always works regardless of toggle.
- The session_id whitelist `^[A-Za-z0-9_-]+$` is defense in depth — real Claude Code session ids are UUIDs which always match this pattern. Users with hand-edited `.session-id` containing slashes / dots / shell metacharacters will get an error.

<p align="center">
  <img src="assets/logo.png" alt="claude-handoff-revive" width="800">
</p>

<p align="center">
  <a href="https://github.com/sofumel/claude-handoff-revive/actions/workflows/ci.yml"><img src="https://github.com/sofumel/claude-handoff-revive/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/sofumel/claude-handoff-revive/releases"><img src="https://img.shields.io/github/v/release/sofumel/claude-handoff-revive" alt="Release"></a>
  <a href="https://github.com/sofumel/claude-handoff-revive/stargazers"><img src="https://img.shields.io/github/stars/sofumel/claude-handoff-revive?style=flat" alt="Stars"></a>
  <a href="https://github.com/sofumel/claude-handoff-revive/graphs/contributors"><img src="https://img.shields.io/github/contributors/sofumel/claude-handoff-revive" alt="Contributors"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/sofumel/claude-handoff-revive" alt="License: MIT"></a>
  <a href="#claude-handoff-revive"><img src="https://img.shields.io/badge/lang-en%20%7C%20ja%20%7C%20zh%20%7C%20zh--TW%20%7C%20ko%20%7C%20es%20%7C%20pt%20%7C%20de%20%7C%20fr%20%7C%20tr-blue" alt="Multi-language"></a>
</p>

<p align="center">
  <em>Continue Claude Code work after a rate / usage / context limit <strong>without</strong> replaying your prior session — typically tens of thousands of tokens, often 100k+ for long sessions.</em>
</p>

<p align="center">
  <a href="#-english">🇺🇸 English</a> ·
  <a href="#-日本語">🇯🇵 日本語</a> ·
  <a href="#-中文">🇨🇳 中文</a> ·
  <a href="#-繁體中文">🇹🇼 繁體中文</a> ·
  <a href="#-한국어">🇰🇷 한국어</a> ·
  <a href="#-español">🇪🇸 Español</a> ·
  <a href="#-português">🇵🇹 Português</a> ·
  <a href="#-deutsch">🇩🇪 Deutsch</a> ·
  <a href="#-français">🇫🇷 Français</a> ·
  <a href="#-türkçe">🇹🇷 Türkçe</a>
</p>

<p align="center">
  <a href="CONTRIBUTING.md">Contributing</a> ·
  <a href="LICENSE">License (MIT)</a>
</p>

---

<a id="-english"></a>
<details open>
<summary><b>🇺🇸 English</b></summary>

<br>

### The problem

When Claude Code shows `You've hit your limit · resets ...`, the standard recovery — `claude --resume` or `claude -c` — reloads **the entire prior conversation** into context. A medium session typically burns tens of thousands of tokens, often 100k+ for long sessions, before you've asked a single question.

### What this skill does

It saves only the minimum needed to continue, structured into `.claude/handoff/current.md` (~1–3k tokens):

- **goal** — what you were trying to accomplish
- **done / wip / todo** — completed, in-progress, not-yet-started tasks
- **next_action** — the concrete next step (`file:line` + exact command)
- **touched_files** — what files were touched and why
- **decisions** — design choices, with the *reason* behind each
- **lessons_learned** — failed attempts and what they taught (optional)

To resume, start a **new session** (don't use `--resume`). The skill reads only that one file and picks up where you left off.

### Install

**Plugin install (recommended) — run these inside Claude Code:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. register marketplace
/plugin install handoff-revive@handoff-revive-marketplace   # 2. install plugin
```

Skill, slash commands, and hooks auto-activate. No `settings.json` editing required.

> **`/plugin isn't available in this environment`?** Your Claude Code version is too old. Check with `claude --version` and update via `brew upgrade claude-code` (Homebrew) or `npm update -g @anthropic-ai/claude-code` (npm). If you can't update, use the manual install below.

**Manual install (always works, no plugin support required):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# Or globally for all projects:
./install.sh --global       # .\install.ps1 -Global
```

For the manual install, optionally enable hooks by merging the snippet from [`HOOK_SETUP.md`](HOOK_SETUP.md) into your `.claude/settings.json` (the plugin install does this automatically).

**Should `.claude/handoff/` be committed to git?** Both work — pick one deliberately:

- **Solo use (default)** — ignore it all; volatile state and snapshots don't belong in history:
  ```gitignore
  .claude/handoff/
  ```
- **Team sharing** — commit only the current handoff; keep snapshots and marker files local:
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

Never commit the dot-marker files (`.turn`, `.usage-flag`, …) or `history/` — they are machine-local state and snapshot noise.

### How to use

**Quick reference:**

| Action | Type this in Claude Code |
|---|---|
| Save handoff | `/handoff-revive:save` |
| Resume in a NEW session | `/handoff-revive:resume` |
| Preview what the next session will read | `/handoff-revive:preview` |
| List saved snapshots | `/handoff-revive:list` |
| Restore a past snapshot | `/handoff-revive:restore <timestamp>` |
| Diff current vs a past snapshot | `/handoff-revive:diff [timestamp]` |
| Post the handoff to a PR as review context | `/handoff-revive:share-to-pr [PR]` (needs `gh`) |
| Show save/resume stats | `/handoff-revive:stats` |
| Diagnose the installation | `/handoff-revive:doctor` |
| Switch handoffs when changing branch | `/handoff-revive:switch` |
| Toggle auto-save for this session | `/handoff-revive:auto on` / `off` / `status` |

When sharing to a PR, the body is built from a **sanitized copy**: the `author_email` line is removed, absolute project/home paths become `<project-root>` / `~`, and known-prefix API keys/tokens (e.g. `sk-`, `ghp_`, `AKIA`, private-key blocks, JWTs) are scanned — if any are detected the post is **aborted** (nothing is ever silently redacted). **Sanitization is best-effort, not a security guarantee**: generic passwords and unprefixed random strings are NOT detected; reviewing the preview remains your responsibility.

#### Step 1 — when you're approaching a rate limit, save

In Claude Code, type the following command:

```
/handoff-revive:save
```

Behind the scenes, the skill runs these steps automatically (all zero-LLM-token where possible):

1. **Detects your language** (10 supported: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) from your message
2. **Pulls changed files from `git status`** — you don't have to remember which files you edited
3. **Writes a schema-conformant handoff** to `.claude/handoff/current.md`
4. **Validates the schema, cleans up dead paths, strips empty sections** — pure shell, no tokens
5. **Displays the estimated savings** in the chat

#### Step 2 — wait for the rate limit to reset

When the time on `resets ...` passes, your usage window opens again.

#### Step 3 — start a NEW session (do NOT use `--resume`)

```bash
claude
```

When the new session starts, the plugin automatically detects the recent handoff. Just run:

```
/handoff-revive:resume
```

Claude reads only that one small file and picks up right where you left off — no need to replay the whole conversation.

#### Optional: turn-count nudge (off by default)

A periodic reminder to checkpoint. It is **off by default** — enable it by setting `HANDOFF_CHECKPOINT_EVERY` to the number of turns between reminders (e.g. `15`):

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

When enabled, every N turns Claude prints:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### Auto-save at 90% / 95% usage (synced with the UI notification)

The `usage-monitor` hook (PostToolUse) reads `rate_limits.five_hour.used_percentage` — the same value that drives Claude Code's "approaching usage limit" notification. When you cross **90%**, Claude auto-saves a full handoff before its next response (no asking, no interruption). At **95%**, it saves again with an urgent notice.

**Per-session opt-out** if you don't want auto-save in the current thread:

```
/handoff-revive:auto off       # disable for THIS session
/handoff-revive:auto on        # re-enable
/handoff-revive:auto status    # show current state + thresholds
```

`/handoff-revive:auto off` only affects the current session — a new session is back to ON. To turn auto-save off **permanently**, set these as environment variables in your shell profile (e.g. add to `~/.zshrc` or `~/.bashrc`, then open a new terminal):

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

To shift the thresholds instead of disabling, set `HANDOFF_AUTO_SAVE_PERCENT=80` (fires earlier) the same way, or configure them per-hook in `settings.json` (see [`HOOK_SETUP.md`](HOOK_SETUP.md)).

### Token budget

| Method | Tokens replayed to resume |
|---|---|
| `claude --resume` | tens of thousands, often 100k+ |
| `claude -c` | tens of thousands, often 100k+ |
| **handoff-revive** | **1,000–3,000** |

### Under the hood (automatic, zero-token)

Every save and resume runs these in pure shell — no extra input, no tokens:

- **Sharing metadata** — each save injects `author`, `branch`, `base_commit`, `created_at` into the frontmatter, so a teammate (or future you) can see who saved it, on which branch, from which commit. `HANDOFF_HIDE_EMAIL=1` omits the email.
- **Freshness check on resume** — compares that metadata against your current git state and warns when the handoff is N commits behind or on a different branch. It also warns when the file is older than `HANDOFF_STALE_DAYS` (default 7; `0` disables) — the age check needs no git, so it works in plain directories too. Purely informational; it never blocks the resume.
- **Snapshot history** — each save also archives a copy to `.claude/handoff/history/<timestamp>.md`. `/handoff-revive:list` shows them, `/handoff-revive:restore <timestamp>` brings one back (non-destructive — the current handoff is archived first), `/handoff-revive:diff [timestamp]` compares. Snapshots past `HANDOFF_HISTORY_RETENTION_DAYS` (default 30) are pruned automatically. A snapshot is the structured work state, not the conversation history.

### Relationship with CLAUDE.md

They answer different questions — don't write the same thing into both:

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| Holds | durable project knowledge: conventions, architecture, commands | **volatile work state**: current goal, WIP, next action |
| Lifetime | months (changes rarely) | hours–days (overwritten per save, snapshotted to history) |
| Loaded | every session, always | only when resuming via `/handoff-revive:resume` |

Writing work state into CLAUDE.md taxes *every* future session with stale context; keeping it in the handoff costs nothing until you actually resume. Opt-in helper (appends a one-line guidance comment to CLAUDE.md, idempotent, never edits existing content):

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-日本語"></a>
<details>
<summary><b>🇯🇵 日本語</b></summary>

<br>

### 解決する問題

`You've hit your limit · resets ...` という制限通知が表示された後、`claude --resume` や `-c` で再開すると、**それまでの会話履歴がまるごと**コンテキストに再ロードされます。中規模のセッションでも数万トークン、長いセッションでは 10 万を超えるトークン分が、まだ何も質問していない段階で消費されてしまいます。

### この skill が提供するもの

作業の続きに必要な最小限の情報だけを構造化して `.claude/handoff/current.md` に保存します（約 1〜3k トークン）。保存される項目:

- **goal** — 何を達成しようとしていたか
- **done / wip / todo** — 完了済み / 進行中 / 未着手のタスク
- **next_action** — 実行可能な次の一手（`file:line` + 具体的なコマンド）
- **touched_files** — 触ったファイルとその理由
- **decisions** — 設計判断と、その**根拠**
- **lessons_learned** — 失敗した試行と、そこから学んだこと（任意）

再開するときは `claude --resume` を使わず、**新規セッション**を起動するだけです。skill がこの 1 ファイルだけを読み込み、すぐに作業を引き継ぎます。

### インストール

**プラグインインストール (推奨) — Claude Code 内で実行:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. マーケットプレイス登録
/plugin install handoff-revive@handoff-revive-marketplace   # 2. プラグインインストール
```

Skill・スラッシュコマンド・hook がすべて自動で有効化されます。`settings.json` の編集は不要。

> **`/plugin isn't available in this environment` と表示された場合**、Claude Code のバージョンが古い可能性があります。`claude --version` で確認し、`brew upgrade claude-code` (Homebrew) または `npm update -g @anthropic-ai/claude-code` (npm) で更新してください。それでも使えない場合は下のマニュアルインストールを使用してください。

**マニュアルインストール (どの環境でも動作):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# 全プロジェクト共通でインストール:
./install.sh --global       # .\install.ps1 -Global
```

マニュアルインストールの場合のみ、[`HOOK_SETUP.md`](HOOK_SETUP.md) のスニペットを `.claude/settings.json` にマージして hooks を有効化してください（プラグインインストールでは自動）。

**`.claude/handoff/` を git にコミットすべき?** どちらでも動きます。用途に合わせて選んでください:

- **個人利用（デフォルト推奨）** — すべて ignore。揮発的な作業状態とスナップショットは履歴に残しません:
  ```gitignore
  .claude/handoff/
  ```
- **チーム共有** — 現在の handoff だけコミットし、スナップショットとマーカーはローカルに留めます:
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

`.turn` や `.usage-flag` などの内部ファイルと、`history/`（スナップショットの置き場）はコミットしないでください。これらはあなたの環境だけで使う一時ファイルで、共有しても意味がありません。

### 使い方

**早見表:**

| やりたいこと | Claude Code に入力するコマンド |
|---|---|
| ハンドオフを保存 | `/handoff-revive:save` |
| **新規セッション** で再開 | `/handoff-revive:resume` |
| 次セッションが読む内容をプレビュー | `/handoff-revive:preview` |
| スナップショット一覧 | `/handoff-revive:list` |
| 過去のスナップショットを復元 | `/handoff-revive:restore <timestamp>` |
| 過去スナップショットとの差分表示 | `/handoff-revive:diff [timestamp]` |
| handoff を PR コメントとして共有 | `/handoff-revive:share-to-pr [PR]`（`gh` 必須） |
| 保存/再開の統計を表示 | `/handoff-revive:stats` |
| インストール状態を診断 | `/handoff-revive:doctor` |
| ブランチ切替時に handoff を入替 | `/handoff-revive:switch` |
| このセッションの自動保存を切り替え | `/handoff-revive:auto on` / `off` / `status` |

PR に投稿する本文は、共有用に**自動で整えたコピー**から作られます。具体的には、メールアドレスの行（`author_email`）を削除し、あなたの PC の絶対パスを `<project-root>` / `~` に置き換え、API キーやトークンらしき文字列（`sk-`、`ghp_`、`AKIA`、秘密鍵、JWT など、よくある形式）が紛れ込んでいないか検査します。見つかった場合は投稿を**中止**します（勝手に伏せ字にすることはありません）。ただし**これはあくまで補助で、安全を保証するものではありません**。ふつうのパスワードや、決まった形式を持たないランダムな文字列は検出できないので、投稿前のプレビュー確認はご自身でお願いします。

#### ステップ 1 — レート制限が近づいたら保存する

Claude Code で、以下のコマンドを入力してください:

```
/handoff-revive:save
```

裏では skill が以下を自動実行します（できる限りトークンを使わずに）:

1. **言語を検出** (10 言語対応: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) — あなたのメッセージから判定
2. **`git status` から変更ファイルを抽出** — どのファイルを編集したか思い出す必要なし
3. **スキーマ通りのハンドオフを `.claude/handoff/current.md` に書き込み**
4. **形式チェック + 存在しないファイルへの参照を自動削除 + 空の項目を除去** — すべてシェルスクリプトだけで処理し（Claude を呼びません）、**トークンを消費しません**
5. **節約見込みをチャットに表示**

#### ステップ 2 — レート制限の解除を待つ

`resets ...` の時刻を過ぎたら、使用枠が回復します。

#### ステップ 3 — **新規セッション**を起動 (`--resume` は使わない)

```bash
claude
```

新しいセッションを開くと、プラグインが自動で最近のハンドオフを検知します。以下のコマンドを入力してください:

```
/handoff-revive:resume
```

Claude はその**小さな 1 ファイルだけ**を読んで、すぐに続きから作業を始めます。会話全体を読み直す必要はありません。

#### 任意機能: 一定ターンごとに保存を促す（デフォルト無効）

定期的に保存を促すリマインドです。**デフォルトでは無効**で、`HANDOFF_CHECKPOINT_EVERY` に「何ターンごとに促すか」を設定すると有効になります（例: `15`）:

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

有効にすると、N ターンごとに次の表示が出ます:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### 90% / 95% 到達で自動保存 (UI 通知と同期)

`usage-monitor` hook (PostToolUse) が `rate_limits.five_hour.used_percentage` を読み取ります — Claude Code の「使用量の上限に近づいています」通知に使われるのと**同じ値**です。**90%** に達すると、Claude が次の応答の前に通常どおり完全なハンドオフを自動保存します（確認なし・作業も中断しません）。**95%** に達すると、緊急の知らせを添えてもう一度保存します。

**このセッションの自動保存をオフにしたい場合:**

```
/handoff-revive:auto off       # このセッションのみ無効化
/handoff-revive:auto on        # 再有効化
/handoff-revive:auto status    # 現在の状態 + 閾値を表示
```

`/handoff-revive:auto off` はこのセッションだけの設定で、新しいセッションでは自動保存が ON に戻ります。**ずっと無効にしたい**場合は、シェルの設定ファイル（macOS/Linux なら `~/.zshrc` や `~/.bashrc` など）に次の2行を追加し、ターミナルを開き直してください:

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

無効化ではなく**発火タイミングを早めたい**だけなら、同じ要領で `HANDOFF_AUTO_SAVE_PERCENT=80` を設定するか、`settings.json` の hook で個別に指定できます（[`HOOK_SETUP.md`](HOOK_SETUP.md) 参照）。

### トークン収支

| 方式 | 再開時に再ロードされるトークン |
|---|---|
| `claude --resume` | 数万、長セッションでは 10 万超も |
| `claude -c` | 数万、長セッションでは 10 万超も |
| **handoff-revive** | **1,000〜3,000** |

### 仕組み（自動・トークン消費ゼロ）

保存と再開のたびに、以下がすべてシェルスクリプトだけで動きます。追加の入力もトークン消費もありません:

- **保存した状況の記録** — 保存のたびに「誰が・どのブランチで・どのコミットから保存したか」（`author` / `branch` / `base_commit` / `created_at`）をファイルの先頭に自動で書き込みます。あとから一目で分かります。`HANDOFF_HIDE_EMAIL=1` でメールアドレスを省略できます。
- **再開時の鮮度チェック** — 上の記録と今の git の状態を見比べて、「保存してから N コミット進んでいる」「別のブランチで保存された」場合に知らせます。保存日時が `HANDOFF_STALE_DAYS`（デフォルト 7 日、`0` で無効）より古いときも知らせます。日数のチェックは git がなくても動くので、git で管理していないフォルダでも使えます。いずれも注意を促すだけで、再開を止めることはありません。
- **スナップショット履歴** — 保存のたびに `.claude/handoff/history/<timestamp>.md` にコピーを残します。`/handoff-revive:list` で一覧、`/handoff-revive:restore <timestamp>` で過去の状態に戻せます（戻す前に今のハンドオフもコピーを取るので、上書きで失われません）。`/handoff-revive:diff [timestamp]` で差分も見られます。`HANDOFF_HISTORY_RETENTION_DAYS`（デフォルト 30 日）を過ぎた古いコピーは自動で削除されます。なお、ここで残るのは goal や next_action といった**作業の要点**だけで、`--resume` のように会話そのものを保存するわけではありません。

### CLAUDE.md との役割分担

CLAUDE.md とハンドオフは目的が違います。同じ内容を両方に書く必要はありません:

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| 持つもの | 永続的なプロジェクト知識: 規約・アーキテクチャ・コマンド | **揮発的な作業状態**: 現在のゴール・WIP・次の一手 |
| 寿命 | 数ヶ月（めったに変わらない） | 数時間〜数日（保存ごとに上書き、履歴にスナップショット） |
| 読み込み | 毎セッション必ず | `/handoff-revive:resume` で再開する時だけ |

作業状態を CLAUDE.md に書いてしまうと、**これから先のすべてのセッション**が毎回その古い情報を読み込むことになります。handoff に置けば、実際に再開するときだけ読み込まれます。必要なら、CLAUDE.md に案内コメントを 1 行だけ追記するヘルパーもあります（何度実行しても重複せず、既存の内容には手を加えません）:

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### ライセンス

MIT — [LICENSE](LICENSE) 参照。

</details>

---

<a id="-中文"></a>
<details>
<summary><b>🇨🇳 中文</b></summary>

<br>

### 要解决的问题

当 Claude Code 显示 `You've hit your limit · resets ...` 时，使用 `claude --resume` 或 `claude -c` 恢复会把**之前的整个会话**重新载入上下文。中等规模会话通常需要数万 tokens，长会话经常超过 10 万——还没问一个问题就已经用掉了。

### 此 skill 提供什么

把恢复所需的**最少信息**以结构化方式保存到 `.claude/handoff/current.md`（约 1–3k tokens）：

- **goal** — 你想完成什么
- **done / wip / todo** — 完成 / 进行中 / 待办
- **next_action** — 可执行的下一步（`file:line` + 具体命令）
- **touched_files** — 涉及的文件及其原因
- **decisions** — 设计决策**及其理由**
- **lessons_learned** — 失败的尝试及其教训（可选）

恢复时启动**新会话**（不要用 `--resume`）。skill 只读取这一个文件即可继续工作。

### 安装

**插件安装 (推荐) — 在 Claude Code 内运行:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. 注册插件市场
/plugin install handoff-revive@handoff-revive-marketplace   # 2. 安装插件
```

Skill、斜杠命令、hooks 全部自动激活，无需编辑 `settings.json`。

> 如果出现 `/plugin isn't available in this environment`，说明 Claude Code 版本过旧。运行 `claude --version` 确认，并通过 `brew upgrade claude-code` 或 `npm update -g @anthropic-ai/claude-code` 升级。

**手动安装 (始终可用):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# 或为所有项目全局安装:
./install.sh --global       # .\install.ps1 -Global
```

手动安装时可选：将 [`HOOK_SETUP.md`](HOOK_SETUP.md) 中的代码片段合并到 `.claude/settings.json` 启用 hooks（插件安装会自动完成）。

**是否应将 `.claude/handoff/` 提交到 git?** 两种都可以——请有意识地选择一种:

- **个人使用（默认）** — 全部忽略；易变的工作状态和快照不该进入历史:
  ```gitignore
  .claude/handoff/
  ```
- **团队共享** — 只提交当前 handoff，快照和标记文件保留在本地:
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

切勿提交点标记文件（`.turn`、`.usage-flag` 等）或 `history/`——它们是机器本地状态和快照噪音。

### 使用方法

**快速参考:**

| 操作 | 在 Claude Code 输入 |
|---|---|
| 保存 handoff | `/handoff-revive:save` |
| 预览下个会话将读取的内容 | `/handoff-revive:preview` |
| 列出已保存的快照 | `/handoff-revive:list` |
| 恢复过去的快照 | `/handoff-revive:restore <timestamp>` |
| 与过去快照对比差异 | `/handoff-revive:diff [timestamp]` |
| 将 handoff 作为 PR 评论分享 | `/handoff-revive:share-to-pr [PR]`（需要 `gh`） |
| 显示保存/恢复统计 | `/handoff-revive:stats` |
| 诊断安装状态 | `/handoff-revive:doctor` |
| 切换分支时交换 handoff | `/handoff-revive:switch` |
| **新会话**中恢复 | `/handoff-revive:resume` |
| 切换本会话的自动保存 | `/handoff-revive:auto on` / `off` / `status` |

向 PR 发布时，正文由**经过自动整理的副本**生成: 删除 `author_email` 行，把项目/主目录的绝对路径替换为 `<project-root>` / `~`，并扫描已知前缀的 API 密钥/令牌（如 `sk-`、`ghp_`、`AKIA`、私钥块、JWT）——一旦检测到就**中止发布**（绝不会悄悄打码）。**整理是尽力而为，并非安全保证**: 普通密码和无前缀的随机字符串无法检测；发布前自行检查预览仍是你的责任。

#### 步骤 1 — 接近速率限制时保存

在 Claude Code 中输入以下命令:

```
/handoff-revive:save
```

幕后，skill 会自动执行以下步骤（尽可能零 token）:

1. **检测语言** (10 种语言: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) —— 从你的消息判断
2. **从 `git status` 提取变更文件** —— 不用回忆改了哪些文件
3. **按 schema 写入 `.claude/handoff/current.md`**
4. **schema 验证 + 删除死路径 + 移除空段落** —— 纯 shell，零 token
5. **在聊天中显示节省估算**

#### 步骤 2 — 等待限制重置

到达 `resets ...` 显示的时间后，使用额度恢复。

#### 步骤 3 — 启动**新会话** (不要用 `--resume`)

```bash
claude
```

新会话启动时，插件会自动检测最近的 handoff。只需运行:

```
/handoff-revive:resume
```

Claude 只读取那个小文件，就能从你离开的地方继续——无需重放整个对话。

#### 可选: 按回合数提醒保存（默认关闭）

定期提醒你保存检查点。**默认关闭**——把 `HANDOFF_CHECKPOINT_EVERY` 设为提醒间隔的回合数即可启用（例如 `15`）:

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

启用后，每 N 个回合 Claude 会打印:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### 90% / 95% 自动保存 (与 UI 通知同步)

`usage-monitor` hook (PostToolUse) 读取 `rate_limits.five_hour.used_percentage`——这与 Claude Code "接近使用上限" 通知所用的值相同。达到 **90%** 时，Claude 会在下次回复前自动完整保存 handoff（无需询问、不打断）。达到 **95%** 时，附上紧急通知再次保存。

**本会话不需要自动保存时（按会话退出）:**

```
/handoff-revive:auto off       # 仅本会话禁用
/handoff-revive:auto on        # 重新启用
/handoff-revive:auto status    # 查看状态 + 阈值
```

`/handoff-revive:auto off` 只影响当前会话——新会话会恢复为开启。要**永久**关闭自动保存，请把下面两行作为环境变量加入 shell 配置文件（例如 `~/.zshrc` 或 `~/.bashrc`），然后打开新终端:

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

若只想调整触发阈值而非关闭，可同样设置 `HANDOFF_AUTO_SAVE_PERCENT=80`（更早触发），或在 `settings.json` 中按 hook 单独配置（见 [`HOOK_SETUP.md`](HOOK_SETUP.md)）。

### Token 收支

| 方式 | 恢复时重放的 token |
|---|---|
| `claude --resume` | 数万，长会话常超 10 万 |
| `claude -c` | 数万，长会话常超 10 万 |
| **handoff-revive** | **1,000–3,000** |

### 内部原理（自动、零 token）

每次保存和恢复都用纯 shell 运行以下内容，无需额外输入、不消耗 token:

- **共享元数据** — 每次保存都会把 `author`、`branch`、`base_commit`、`created_at` 注入 frontmatter，这样队友（或未来的你）能看到是谁、在哪个分支、从哪个提交保存的。`HANDOFF_HIDE_EMAIL=1` 可省略邮箱。
- **恢复时的新鲜度检查** — 把上述元数据与当前 git 状态对比，当 handoff 落后 N 个提交或处于不同分支时提示。当文件比 `HANDOFF_STALE_DAYS`（默认 7，`0` 关闭）更旧时也会提示——日期检查不需要 git，所以在非 git 目录也能用。纯属提示，绝不阻止恢复。
- **快照历史** — 每次保存还会把副本归档到 `.claude/handoff/history/<timestamp>.md`。`/handoff-revive:list` 列出，`/handoff-revive:restore <timestamp>` 取回某个（非破坏性——会先归档当前 handoff），`/handoff-revive:diff [timestamp]` 比较。超过 `HANDOFF_HISTORY_RETENTION_DAYS`（默认 30）的快照会自动清理。快照保存的是结构化的工作状态，而非对话历史。

### 与 CLAUDE.md 的分工

它们回答不同的问题——不要把同样的内容写进两者:

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| 存放 | 持久的项目知识: 约定、架构、命令 | **易变的工作状态**: 当前目标、WIP、下一步 |
| 寿命 | 数月（很少改动） | 数小时–数天（每次保存覆盖，归档到历史） |
| 加载 | 每个会话，总是 | 仅在通过 `/handoff-revive:resume` 恢复时 |

把工作状态写进 CLAUDE.md，会让*以后的每个会话*都背上过时的上下文；放在 handoff 里，则在你真正恢复前不花任何代价。可选的辅助脚本（向 CLAUDE.md 追加一行说明注释，幂等，绝不修改已有内容）:

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-繁體中文"></a>
<details>
<summary><b>🇹🇼 繁體中文</b></summary>

<br>

### 要解決的問題

當 Claude Code 顯示 `You've hit your limit · resets ...` 時，使用 `claude --resume` 或 `claude -c` 恢復會把**之前的整個會話**重新載入上下文。中等規模對話通常需要數萬 tokens，長對話經常超過 10 萬——還沒問一個問題就已經用掉了。

### 此 skill 提供什麼

把恢復所需的**最少資訊**以結構化方式儲存到 `.claude/handoff/current.md`（約 1–3k tokens）：

- **goal** — 你想完成什麼
- **done / wip / todo** — 完成 / 進行中 / 待辦
- **next_action** — 可執行的下一步（`file:line` + 具體命令）
- **touched_files** — 涉及的檔案及其原因
- **decisions** — 設計決策**及其理由**
- **lessons_learned** — 失敗的嘗試及其教訓（可選）

恢復時啟動**新會話**（不要用 `--resume`）。skill 只讀取這一個檔案即可繼續工作。

### 安裝

**外掛程式安裝 (推薦) — 在 Claude Code 內執行:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. 註冊 marketplace
/plugin install handoff-revive@handoff-revive-marketplace   # 2. 安裝外掛
```

Skill、斜線命令、hooks 全部自動啟用，無需編輯 `settings.json`。

> 如果出現 `/plugin isn't available in this environment`，說明 Claude Code 版本過舊。執行 `claude --version` 確認，並透過 `brew upgrade claude-code` 或 `npm update -g @anthropic-ai/claude-code` 升級。

**手動安裝 (始終可用):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# 或為所有專案全域安裝:
./install.sh --global       # .\install.ps1 -Global
```

手動安裝時可選：將 [`HOOK_SETUP.md`](HOOK_SETUP.md) 中的程式碼片段合併到 `.claude/settings.json` 以啟用 hooks（外掛安裝會自動完成）。

**是否應將 `.claude/handoff/` 提交到 git?** 兩種都可以——請有意識地選擇一種:

- **個人使用（預設）** — 全部忽略；易變的工作狀態和快照不該進入歷史:
  ```gitignore
  .claude/handoff/
  ```
- **團隊共享** — 只提交目前的 handoff，快照和標記檔案保留在本地:
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

切勿提交點標記檔案（`.turn`、`.usage-flag` 等）或 `history/`——它們是機器本地狀態和快照雜訊。

### 使用方式

**快速參考:**

| 操作 | 在 Claude Code 輸入 |
|---|---|
| 儲存 handoff | `/handoff-revive:save` |
| 預覽下個會話將讀取的內容 | `/handoff-revive:preview` |
| 列出已儲存的快照 | `/handoff-revive:list` |
| 還原過去的快照 | `/handoff-revive:restore <timestamp>` |
| 與過去快照比較差異 | `/handoff-revive:diff [timestamp]` |
| 將 handoff 作為 PR 留言分享 | `/handoff-revive:share-to-pr [PR]`（需要 `gh`） |
| 顯示儲存/恢復統計 | `/handoff-revive:stats` |
| 診斷安裝狀態 | `/handoff-revive:doctor` |
| 切換分支時交換 handoff | `/handoff-revive:switch` |
| **新會話**中恢復 | `/handoff-revive:resume` |
| 切換本會話的自動儲存 | `/handoff-revive:auto on` / `off` / `status` |

向 PR 發布時，正文由**經過自動整理的副本**產生: 刪除 `author_email` 行，把專案/家目錄的絕對路徑替換為 `<project-root>` / `~`，並掃描已知前綴的 API 金鑰/權杖（如 `sk-`、`ghp_`、`AKIA`、私鑰區塊、JWT）——一旦偵測到就**中止發布**（絕不會默默遮蔽）。**整理是盡力而為，並非安全保證**: 普通密碼和無前綴的隨機字串無法偵測；發布前自行檢查預覽仍是你的責任。

#### 步驟 1 — 接近速率限制時儲存

在 Claude Code 中輸入以下命令:

```
/handoff-revive:save
```

幕後，skill 會自動執行以下步驟（盡可能零 token）:

1. **偵測語言** (10 種語言: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) —— 從你的訊息判斷
2. **從 `git status` 擷取變更檔案** —— 不用回想改了哪些檔案
3. **按 schema 寫入 `.claude/handoff/current.md`**
4. **schema 驗證 + 刪除死路徑 + 移除空段落** —— 純 shell，零 token
5. **在聊天中顯示節省估算**

#### 步驟 2 — 等待限制重置

到達 `resets ...` 顯示的時間後，使用額度恢復。

#### 步驟 3 — 啟動**新會話** (不要用 `--resume`)

```bash
claude
```

新會話啟動時，外掛會自動偵測最近的 handoff。只需執行:

```
/handoff-revive:resume
```

Claude 只讀取那個小檔案，就能從你離開的地方繼續——無需重放整個對話。

#### 可選: 依回合數提醒儲存（預設關閉）

定期提醒你儲存檢查點。**預設關閉**——把 `HANDOFF_CHECKPOINT_EVERY` 設為提醒間隔的回合數即可啟用（例如 `15`）:

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

啟用後，每 N 個回合 Claude 會印出:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### 90% / 95% 自動儲存 (與 UI 通知同步)

`usage-monitor` hook (PostToolUse) 讀取 `rate_limits.five_hour.used_percentage`——這與 Claude Code「接近使用上限」通知所用的值相同。達到 **90%** 時，Claude 會在下次回覆前自動完整儲存 handoff（無需詢問、不中斷）。達到 **95%** 時，附上緊急通知再次儲存。

**本會話不需要自動儲存時（依會話退出）:**

```
/handoff-revive:auto off       # 僅本會話停用
/handoff-revive:auto on        # 重新啟用
/handoff-revive:auto status    # 查看狀態 + 閾值
```

`/handoff-revive:auto off` 只影響目前的會話——新會話會恢復為開啟。要**永久**關閉自動儲存，請把下面兩行作為環境變數加入 shell 設定檔（例如 `~/.zshrc` 或 `~/.bashrc`），然後開啟新終端機:

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

若只想調整觸發閾值而非關閉，可同樣設定 `HANDOFF_AUTO_SAVE_PERCENT=80`（更早觸發），或在 `settings.json` 中按 hook 單獨設定（見 [`HOOK_SETUP.md`](HOOK_SETUP.md)）。

### Token 收支

| 方式 | 恢復時重放的 token |
|---|---|
| `claude --resume` | 數萬，長對話常超 10 萬 |
| `claude -c` | 數萬，長對話常超 10 萬 |
| **handoff-revive** | **1,000–3,000** |

### 內部原理（自動、零 token）

每次儲存和恢復都用純 shell 執行以下內容，無需額外輸入、不消耗 token:

- **共享中繼資料** — 每次儲存都會把 `author`、`branch`、`base_commit`、`created_at` 注入 frontmatter，這樣隊友（或未來的你）能看到是誰、在哪個分支、從哪個提交儲存的。`HANDOFF_HIDE_EMAIL=1` 可省略電子郵件。
- **恢復時的新鮮度檢查** — 把上述中繼資料與目前 git 狀態對比，當 handoff 落後 N 個提交或處於不同分支時提示。當檔案比 `HANDOFF_STALE_DAYS`（預設 7，`0` 關閉）更舊時也會提示——日期檢查不需要 git，所以在非 git 目錄也能用。純屬提示，絕不阻止恢復。
- **快照歷史** — 每次儲存還會把副本封存到 `.claude/handoff/history/<timestamp>.md`。`/handoff-revive:list` 列出，`/handoff-revive:restore <timestamp>` 取回某個（非破壞性——會先封存目前的 handoff），`/handoff-revive:diff [timestamp]` 比較。超過 `HANDOFF_HISTORY_RETENTION_DAYS`（預設 30）的快照會自動清理。快照儲存的是結構化的工作狀態，而非對話歷史。

### 與 CLAUDE.md 的分工

它們回答不同的問題——不要把同樣的內容寫進兩者:

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| 存放 | 持久的專案知識: 慣例、架構、命令 | **易變的工作狀態**: 目前目標、WIP、下一步 |
| 壽命 | 數月（很少改動） | 數小時–數天（每次儲存覆寫，封存到歷史） |
| 載入 | 每個會話，總是 | 僅在透過 `/handoff-revive:resume` 恢復時 |

把工作狀態寫進 CLAUDE.md，會讓*以後的每個會話*都背上過時的上下文；放在 handoff 裡，則在你真正恢復前不花任何代價。可選的輔助腳本（向 CLAUDE.md 追加一行說明註解，冪等，絕不修改既有內容）:

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-한국어"></a>
<details>
<summary><b>🇰🇷 한국어</b></summary>

<br>

### 해결하는 문제

`You've hit your limit · resets ...` 메시지가 나타난 뒤 `claude --resume` 또는 `-c` 로 재개하면 **이전 세션 전체** 가 컨텍스트로 다시 로드됩니다. 중간 규모 세션이라면 수만 토큰, 긴 세션에서는 10만+ 토큰이 아무 질문하기도 전에 사라집니다.

### 이 skill 이 제공하는 것

작업 재개에 필요한 최소 정보만을 구조화하여 `.claude/handoff/current.md` 에 저장합니다(약 1–3k tokens):

- **goal** — 무엇을 달성하려 했는가
- **done / wip / todo** — 완료 / 진행 중 / 대기
- **next_action** — 실행 가능한 다음 단계 (`file:line` + 구체적 명령)
- **touched_files** — 다룬 파일과 그 이유
- **decisions** — 설계 결정과 **근거**
- **lessons_learned** — 실패한 시도와 거기서 배운 것 (선택)

재개할 때는 `--resume` 을 쓰지 말고 **새 세션**을 시작합니다. skill 이 그 파일 하나만 읽고 즉시 작업을 이어갑니다.

### 설치

**플러그인 설치 (권장) — Claude Code 안에서 실행:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. 마켓플레이스 등록
/plugin install handoff-revive@handoff-revive-marketplace   # 2. 플러그인 설치
```

Skill・슬래시 명령・hooks 가 모두 자동 활성화됩니다. `settings.json` 편집은 필요 없습니다.

> `/plugin isn't available in this environment` 메시지가 나오면 Claude Code 버전이 오래되었습니다. `claude --version` 으로 확인하고 `brew upgrade claude-code` 또는 `npm update -g @anthropic-ai/claude-code` 로 업데이트하세요.

**수동 설치 (항상 동작):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# 또는 모든 프로젝트에 전역 설치:
./install.sh --global       # .\install.ps1 -Global
```

수동 설치 시 선택 사항: [`HOOK_SETUP.md`](HOOK_SETUP.md) 의 스니펫을 `.claude/settings.json` 에 병합하면 hooks 가 활성화됩니다(플러그인 설치는 자동).

**`.claude/handoff/` 를 git 에 커밋해야 할까?** 둘 다 동작합니다 — 의도적으로 하나를 고르세요:

- **개인 사용 (기본)** — 전부 무시; 휘발성 작업 상태와 스냅샷은 히스토리에 둘 필요가 없습니다:
  ```gitignore
  .claude/handoff/
  ```
- **팀 공유** — 현재 handoff 만 커밋하고 스냅샷과 마커 파일은 로컬에 둡니다:
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

점 마커 파일(`.turn`, `.usage-flag` 등)이나 `history/` 는 절대 커밋하지 마세요 — 머신 로컬 상태이자 스냅샷 노이즈입니다.

### 사용법

**빠른 참조:**

| 작업 | Claude Code 입력 |
|---|---|
| 핸드오프 저장 | `/handoff-revive:save` |
| 다음 세션이 읽을 내용 미리보기 | `/handoff-revive:preview` |
| 저장된 스냅샷 목록 | `/handoff-revive:list` |
| 과거 스냅샷 복원 | `/handoff-revive:restore <timestamp>` |
| 과거 스냅샷과의 차이 보기 | `/handoff-revive:diff [timestamp]` |
| handoff 를 PR 코멘트로 공유 | `/handoff-revive:share-to-pr [PR]` (`gh` 필요) |
| 저장/재개 통계 보기 | `/handoff-revive:stats` |
| 설치 상태 진단 | `/handoff-revive:doctor` |
| 브랜치 전환 시 handoff 교체 | `/handoff-revive:switch` |
| **새 세션** 에서 재개 | `/handoff-revive:resume` |
| 이 세션 자동 저장 토글 | `/handoff-revive:auto on` / `off` / `status` |

PR 에 게시할 때 본문은 **자동 정리된 사본**에서 생성됩니다: `author_email` 줄을 제거하고, 프로젝트/홈 절대 경로를 `<project-root>` / `~` 로 바꾸며, 알려진 접두사의 API 키/토큰(`sk-`, `ghp_`, `AKIA`, 개인 키 블록, JWT 등)을 검사합니다 — 발견되면 게시를 **중단**합니다(절대 조용히 가리지 않습니다). **정리는 최선의 노력일 뿐 보안 보장이 아닙니다**: 일반 비밀번호나 접두사 없는 무작위 문자열은 감지되지 않으므로, 게시 전 미리보기 확인은 본인 책임입니다.

#### 단계 1 — 사용량 한도가 가까워지면 저장

Claude Code 에서 다음 명령을 입력하세요:

```
/handoff-revive:save
```

뒤에서 skill 이 다음 단계를 자동으로 실행합니다(가능한 한 0 토큰):

1. **언어 감지** (10개 언어 지원: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) — 메시지에서 판단
2. **`git status` 에서 변경 파일 추출** — 어떤 파일을 고쳤는지 기억할 필요 없음
3. **스키마대로 `.claude/handoff/current.md` 에 저장**
4. **스키마 검증 + 죽은 경로 제거 + 빈 섹션 제거** — 순 shell, 0 토큰
5. **채팅에 절약량 표시**

#### 단계 2 — 한도 리셋 대기

`resets ...` 시간이 지나면 사용량이 복구됩니다.

#### 단계 3 — **새 세션** 시작 (`--resume` 사용 금지)

```bash
claude
```

새 세션을 시작하면 플러그인이 최근 핸드오프를 자동으로 감지합니다. 다음만 실행하세요:

```
/handoff-revive:resume
```

Claude 는 그 작은 파일 하나만 읽고 떠난 지점에서 바로 이어갑니다 — 전체 대화를 다시 재생할 필요가 없습니다.

#### 선택: 턴 수 기반 저장 알림 (기본 비활성화)

체크포인트 저장을 주기적으로 알립니다. **기본적으로 비활성화** — `HANDOFF_CHECKPOINT_EVERY` 에 알림 간격 턴 수를 설정하면 활성화됩니다(예: `15`):

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

활성화하면 N 턴마다 Claude 가 다음을 출력합니다:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### 90% / 95% 자동 저장 (UI 알림과 동기)

`usage-monitor` hook (PostToolUse) 이 `rate_limits.five_hour.used_percentage` 를 읽습니다 — Claude Code 의 "사용량 한도 접근" 알림과 같은 값입니다. **90%** 에 도달하면 Claude 가 다음 응답 전에 완전한 핸드오프를 자동 저장합니다(질문 없이, 중단 없이). **95%** 에서는 긴급 알림과 함께 다시 저장합니다.

**이 세션에서 자동 저장을 원치 않으면 (세션별 해제):**

```
/handoff-revive:auto off       # 이 세션만 비활성화
/handoff-revive:auto on        # 다시 활성화
/handoff-revive:auto status    # 상태 + 임계값 확인
```

`/handoff-revive:auto off` 는 현재 세션에만 영향을 줍니다 — 새 세션은 다시 켜집니다. 자동 저장을 **영구히** 끄려면 아래 두 줄을 셸 프로필(예: `~/.zshrc` 또는 `~/.bashrc`)에 환경 변수로 추가하고 새 터미널을 여세요:

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

끄는 대신 임계값만 바꾸고 싶다면 같은 방식으로 `HANDOFF_AUTO_SAVE_PERCENT=80`(더 일찍 발동)을 설정하거나, `settings.json` 에서 hook 별로 지정하세요(see [`HOOK_SETUP.md`](HOOK_SETUP.md)).

### 토큰 수지

| 방식 | 재개 시 재생되는 토큰 |
|---|---|
| `claude --resume` | 수만, 긴 세션은 10만+ |
| `claude -c` | 수만, 긴 세션은 10만+ |
| **handoff-revive** | **1,000–3,000** |

### 내부 동작 (자동, 0 토큰)

모든 저장과 재개는 순 shell 로 다음을 실행합니다 — 추가 입력도, 토큰도 없습니다:

- **공유 메타데이터** — 저장할 때마다 `author`, `branch`, `base_commit`, `created_at` 를 frontmatter 에 주입하므로, 팀원(또는 미래의 당신)이 누가・어느 브랜치에서・어느 커밋에서 저장했는지 알 수 있습니다. `HANDOFF_HIDE_EMAIL=1` 로 이메일을 생략할 수 있습니다.
- **재개 시 신선도 검사** — 위 메타데이터를 현재 git 상태와 비교하여 handoff 가 N 커밋 뒤처졌거나 다른 브랜치일 때 경고합니다. 파일이 `HANDOFF_STALE_DAYS`(기본 7, `0` 이면 비활성화)보다 오래되었을 때도 경고합니다 — 날짜 검사는 git 이 필요 없으므로 git 이 아닌 디렉터리에서도 동작합니다. 순전히 정보 제공용이며 재개를 막지 않습니다.
- **스냅샷 히스토리** — 저장할 때마다 사본을 `.claude/handoff/history/<timestamp>.md` 에 보관합니다. `/handoff-revive:list` 로 목록을 보고, `/handoff-revive:restore <timestamp>` 로 되돌리며(비파괴적 — 현재 handoff 를 먼저 보관함), `/handoff-revive:diff [timestamp]` 로 비교합니다. `HANDOFF_HISTORY_RETENTION_DAYS`(기본 30)를 지난 스냅샷은 자동 정리됩니다. 스냅샷은 대화 기록이 아니라 구조화된 작업 상태입니다.

### CLAUDE.md 와의 역할 분담

둘은 서로 다른 질문에 답합니다 — 같은 내용을 양쪽에 쓰지 마세요:

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| 담는 것 | 영속적 프로젝트 지식: 규약・아키텍처・명령 | **휘발성 작업 상태**: 현재 목표・WIP・다음 단계 |
| 수명 | 수개월 (거의 안 바뀜) | 수시간–수일 (저장마다 덮어쓰기, 히스토리에 스냅샷) |
| 로드 | 매 세션, 항상 | `/handoff-revive:resume` 로 재개할 때만 |

작업 상태를 CLAUDE.md 에 쓰면 *앞으로의 모든 세션*이 오래된 컨텍스트를 떠안게 됩니다; handoff 에 두면 실제로 재개할 때까지 아무 비용도 들지 않습니다. 선택형 헬퍼(안내 주석 한 줄을 CLAUDE.md 에 추가, 멱등, 기존 내용은 절대 수정하지 않음):

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-español"></a>
<details>
<summary><b>🇪🇸 Español</b></summary>

<br>

### El problema

Cuando Claude Code muestra `You've hit your limit · resets ...`, la recuperación habitual — `claude --resume` o `-c` — recarga **toda la conversación anterior** en el contexto. Una sesión mediana consume decenas de miles de tokens, a menudo 100k+ en sesiones largas, antes de hacer una sola pregunta.

### Lo que ofrece este skill

Guarda solo el mínimo necesario para continuar, estructurado en `.claude/handoff/current.md` (~1–3k tokens):

- **goal** — qué intentabas lograr
- **done / wip / todo** — completado / en progreso / pendiente
- **next_action** — siguiente paso ejecutable (`file:line` + comando exacto)
- **touched_files** — archivos tocados y su razón
- **decisions** — decisiones de diseño y **el por qué**
- **lessons_learned** — intentos fallidos y lo aprendido (opcional)

Para reanudar, inicia una **sesión nueva** (NO uses `--resume`). El skill lee solo ese archivo y continúa.

### Instalación

**Plugin (recomendado) — ejecutar dentro de Claude Code:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. registrar marketplace
/plugin install handoff-revive@handoff-revive-marketplace   # 2. instalar plugin
```

Skill, comandos slash y hooks se activan automáticamente. No hay que editar `settings.json`.

> Si aparece `/plugin isn't available in this environment`, tu versión de Claude Code es antigua. Verifica con `claude --version` y actualiza con `brew upgrade claude-code` o `npm update -g @anthropic-ai/claude-code`.

**Instalación manual (siempre funciona):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# O globalmente para todos los proyectos:
./install.sh --global       # .\install.ps1 -Global
```

Para la instalación manual, opcionalmente habilita los hooks fusionando el fragmento de [`HOOK_SETUP.md`](HOOK_SETUP.md) en tu `.claude/settings.json` (la instalación del plugin lo hace automáticamente).

**¿Debes commitear `.claude/handoff/` a git?** Ambas opciones funcionan — elige una a conciencia:

- **Uso individual (por defecto)** — ignóralo todo; el estado volátil y los snapshots no pertenecen al historial:
  ```gitignore
  .claude/handoff/
  ```
- **Compartir en equipo** — commitea solo el handoff actual; mantén snapshots y marcadores en local:
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

Nunca commitees los archivos punto-marcador (`.turn`, `.usage-flag`, …) ni `history/` — son estado local de la máquina y ruido de snapshots.

### Cómo usar

**Referencia rápida:**

| Acción | Escribe en Claude Code |
|---|---|
| Guardar handoff | `/handoff-revive:save` |
| Previsualizar lo que leerá la próxima sesión | `/handoff-revive:preview` |
| Listar snapshots guardados | `/handoff-revive:list` |
| Restaurar un snapshot anterior | `/handoff-revive:restore <timestamp>` |
| Diff con un snapshot anterior | `/handoff-revive:diff [timestamp]` |
| Publicar el handoff en un PR | `/handoff-revive:share-to-pr [PR]` (requiere `gh`) |
| Ver estadísticas de guardado/reanudación | `/handoff-revive:stats` |
| Diagnosticar la instalación | `/handoff-revive:doctor` |
| Cambiar de handoff al cambiar de rama | `/handoff-revive:switch` |
| Reanudar en una **sesión nueva** | `/handoff-revive:resume` |
| Alternar auto-guardado en esta sesión | `/handoff-revive:auto on` / `off` / `status` |

Al publicar en un PR, el cuerpo se construye a partir de una **copia saneada**: se elimina la línea `author_email`, las rutas absolutas del proyecto/home pasan a `<project-root>` / `~`, y se buscan claves/tokens de API con prefijos conocidos (p. ej. `sk-`, `ghp_`, `AKIA`, bloques de clave privada, JWT) — si se detecta alguno la publicación se **aborta** (nunca se censura en silencio). **El saneamiento es de mejor esfuerzo, no una garantía de seguridad**: las contraseñas genéricas y las cadenas aleatorias sin prefijo NO se detectan; revisar la vista previa sigue siendo tu responsabilidad.

#### Paso 1 — al acercarte al límite, guarda

En Claude Code, escribe el siguiente comando:

```
/handoff-revive:save
```

Por detrás, el skill ejecuta estos pasos automáticamente (sin tokens siempre que es posible):

1. **Detecta tu idioma** (10 idiomas: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) a partir de tu mensaje
2. **Extrae los archivos cambiados de `git status`** — no tienes que recordar qué editaste
3. **Escribe un handoff conforme al schema** en `.claude/handoff/current.md`
4. **Valida el schema, elimina rutas muertas y quita secciones vacías** — shell puro, cero tokens
5. **Muestra el ahorro estimado** en el chat

#### Paso 2 — espera al reset del límite

Cuando pase la hora de `resets ...`, tu ventana de uso vuelve a abrirse.

#### Paso 3 — inicia una **sesión nueva** (NO uses `--resume`)

```bash
claude
```

Cuando arranca la nueva sesión, el plugin detecta automáticamente el handoff reciente. Solo ejecuta:

```
/handoff-revive:resume
```

Claude lee solo ese pequeño archivo y retoma justo donde lo dejaste — sin reproducir toda la conversación.

#### Opcional: aviso por número de turnos (desactivado por defecto)

Un recordatorio periódico para hacer checkpoint. Está **desactivado por defecto** — actívalo poniendo `HANDOFF_CHECKPOINT_EVERY` al número de turnos entre recordatorios (p. ej. `15`):

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

Cuando está activado, cada N turnos Claude imprime:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### Auto-guardado al 90% / 95% (sincronizado con la notificación de la UI)

El hook `usage-monitor` (PostToolUse) lee `rate_limits.five_hour.used_percentage` — el mismo valor que dispara la notificación de "te acercas al límite de uso" de Claude Code. Al cruzar el **90%**, Claude auto-guarda un handoff completo antes de su siguiente respuesta (sin preguntar, sin interrumpir). Al **95%**, vuelve a guardar con un aviso urgente.

**Exclusión por sesión** si no quieres auto-guardado en el hilo actual:

```
/handoff-revive:auto off       # desactivar SOLO esta sesión
/handoff-revive:auto on        # reactivar
/handoff-revive:auto status    # ver estado + umbrales
```

`/handoff-revive:auto off` solo afecta a la sesión actual — una sesión nueva vuelve a ON. Para desactivar el auto-guardado de forma **permanente**, define estas variables de entorno en el perfil de tu shell (p. ej. añádelas a `~/.zshrc` o `~/.bashrc`, y abre una terminal nueva):

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

Para cambiar los umbrales en lugar de desactivarlos, define `HANDOFF_AUTO_SAVE_PERCENT=80` (se dispara antes) de la misma forma, o configúralos por hook en `settings.json` (ver [`HOOK_SETUP.md`](HOOK_SETUP.md)).

### Presupuesto de tokens

| Método | Tokens reproducidos al reanudar |
|---|---|
| `claude --resume` | decenas de miles, a menudo 100k+ |
| `claude -c` | decenas de miles, a menudo 100k+ |
| **handoff-revive** | **1.000–3.000** |

### Bajo el capó (automático, cero tokens)

Cada guardado y reanudación ejecuta esto en shell puro — sin entrada extra, sin tokens:

- **Metadatos de compartición** — cada guardado inyecta `author`, `branch`, `base_commit`, `created_at` en el frontmatter, para que un compañero (o tu yo futuro) vea quién lo guardó, en qué rama y desde qué commit. `HANDOFF_HIDE_EMAIL=1` omite el email.
- **Comprobación de frescura al reanudar** — compara esos metadatos con tu estado git actual y avisa cuando el handoff está N commits atrás o en otra rama. También avisa cuando el archivo es más viejo que `HANDOFF_STALE_DAYS` (por defecto 7; `0` lo desactiva) — la comprobación de edad no necesita git, así que funciona también en carpetas sin git. Es puramente informativo; nunca bloquea la reanudación.
- **Historial de snapshots** — cada guardado archiva además una copia en `.claude/handoff/history/<timestamp>.md`. `/handoff-revive:list` los muestra, `/handoff-revive:restore <timestamp>` recupera uno (no destructivo — el handoff actual se archiva primero), `/handoff-revive:diff [timestamp]` compara. Los snapshots más allá de `HANDOFF_HISTORY_RETENTION_DAYS` (por defecto 30) se podan automáticamente. Un snapshot es el estado de trabajo estructurado, no el historial de la conversación.

### Relación con CLAUDE.md

Responden a preguntas distintas — no escribas lo mismo en ambos:

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| Contiene | conocimiento duradero del proyecto: convenciones, arquitectura, comandos | **estado de trabajo volátil**: objetivo actual, WIP, siguiente acción |
| Vida | meses (cambia rara vez) | horas–días (se sobrescribe en cada guardado, con snapshot al historial) |
| Se carga | cada sesión, siempre | solo al reanudar con `/handoff-revive:resume` |

Escribir el estado de trabajo en CLAUDE.md grava *cada* sesión futura con contexto obsoleto; mantenerlo en el handoff no cuesta nada hasta que realmente reanudas. Ayudante opcional (añade un comentario de una línea a CLAUDE.md, idempotente, nunca edita el contenido existente):

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-português"></a>
<details>
<summary><b>🇵🇹 Português</b></summary>

<br>

### O problema

Quando o Claude Code mostra `You've hit your limit · resets ...`, a recuperação habitual — `claude --resume` ou `-c` — recarrega **toda a conversa anterior** no contexto. Uma sessão média gasta dezenas de milhares de tokens, frequentemente 100k+ em sessões longas, antes de fazer uma única pergunta.

### O que esta skill faz

Guarda apenas o mínimo necessário para continuar, estruturado em `.claude/handoff/current.md` (~1–3k tokens):

- **goal** — o que estavas a tentar alcançar
- **done / wip / todo** — concluído / em curso / pendente
- **next_action** — próximo passo executável (`file:line` + comando exato)
- **touched_files** — ficheiros tocados e a razão
- **decisions** — decisões de design **e o porquê**
- **lessons_learned** — tentativas falhadas e o que ensinaram (opcional)

Para retomar, inicia uma **sessão nova** (NÃO uses `--resume`). A skill lê apenas esse ficheiro e continua.

### Instalação

**Plugin (recomendado) — executar dentro do Claude Code:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. registar marketplace
/plugin install handoff-revive@handoff-revive-marketplace   # 2. instalar plugin
```

Skill, comandos slash e hooks ativam-se automaticamente. Não é preciso editar `settings.json`.

> Se aparecer `/plugin isn't available in this environment`, a tua versão do Claude Code é antiga. Verifica com `claude --version` e atualiza via `brew upgrade claude-code` ou `npm update -g @anthropic-ai/claude-code`.

**Instalação manual (sempre funciona):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# Ou globalmente para todos os projetos:
./install.sh --global       # .\install.ps1 -Global
```

Para a instalação manual, opcionalmente ativa os hooks juntando o trecho de [`HOOK_SETUP.md`](HOOK_SETUP.md) ao teu `.claude/settings.json` (a instalação do plugin faz isto automaticamente).

**Deves fazer commit de `.claude/handoff/` no git?** Ambas funcionam — escolhe uma deliberadamente:

- **Uso individual (padrão)** — ignora tudo; o estado volátil e os snapshots não pertencem ao histórico:
  ```gitignore
  .claude/handoff/
  ```
- **Partilha em equipa** — faz commit apenas do handoff atual; mantém snapshots e marcadores localmente:
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

Nunca faças commit dos ficheiros ponto-marcador (`.turn`, `.usage-flag`, …) nem de `history/` — são estado local da máquina e ruído de snapshots.

### Uso

**Referência rápida:**

| Ação | Escreve no Claude Code |
|---|---|
| Guardar handoff | `/handoff-revive:save` |
| Pré-visualizar o que a próxima sessão lerá | `/handoff-revive:preview` |
| Listar snapshots guardados | `/handoff-revive:list` |
| Restaurar um snapshot anterior | `/handoff-revive:restore <timestamp>` |
| Diff com um snapshot anterior | `/handoff-revive:diff [timestamp]` |
| Publicar o handoff num PR | `/handoff-revive:share-to-pr [PR]` (requer `gh`) |
| Ver estatísticas de guardado/retoma | `/handoff-revive:stats` |
| Diagnosticar a instalação | `/handoff-revive:doctor` |
| Trocar de handoff ao mudar de ramo | `/handoff-revive:switch` |
| Retomar numa **sessão nova** | `/handoff-revive:resume` |
| Alternar auto-save nesta sessão | `/handoff-revive:auto on` / `off` / `status` |

Ao publicar num PR, o corpo é construído a partir de uma **cópia higienizada**: a linha `author_email` é removida, os caminhos absolutos do projeto/home passam a `<project-root>` / `~`, e procuram-se chaves/tokens de API com prefixos conhecidos (p. ex. `sk-`, `ghp_`, `AKIA`, blocos de chave privada, JWT) — se algum for detetado a publicação é **abortada** (nada é censurado em silêncio). **A higienização é de melhor esforço, não uma garantia de segurança**: palavras-passe genéricas e strings aleatórias sem prefixo NÃO são detetadas; rever a pré-visualização continua a ser da tua responsabilidade.

#### Passo 1 — ao aproximares-te do limite, guarda

No Claude Code, escreve o seguinte comando:

```
/handoff-revive:save
```

Nos bastidores, a skill executa estes passos automaticamente (sem tokens sempre que possível):

1. **Deteta o teu idioma** (10 idiomas: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) a partir da tua mensagem
2. **Extrai os ficheiros alterados de `git status`** — não tens de lembrar o que editaste
3. **Escreve um handoff conforme o schema** em `.claude/handoff/current.md`
4. **Valida o schema, elimina caminhos mortos e remove secções vazias** — shell puro, zero tokens
5. **Mostra a poupança estimada** no chat

#### Passo 2 — espera pelo reset do limite

Quando passar a hora de `resets ...`, a tua janela de uso reabre.

#### Passo 3 — inicia uma **sessão nova** (NÃO uses `--resume`)

```bash
claude
```

Quando a nova sessão arranca, o plugin deteta automaticamente o handoff recente. Basta executar:

```
/handoff-revive:resume
```

A Claude lê apenas esse pequeno ficheiro e retoma exatamente onde paraste — sem repetir toda a conversa.

#### Opcional: aviso por número de turnos (desativado por defeito)

Um lembrete periódico para fazer checkpoint. Está **desativado por defeito** — ativa-o definindo `HANDOFF_CHECKPOINT_EVERY` com o número de turnos entre lembretes (p. ex. `15`):

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

Quando ativado, a cada N turnos a Claude imprime:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### Auto-guardado a 90% / 95% (sincronizado com a notificação da UI)

O hook `usage-monitor` (PostToolUse) lê `rate_limits.five_hour.used_percentage` — o mesmo valor que aciona a notificação de "a aproximar-te do limite de uso" da Claude Code. Ao cruzar os **90%**, a Claude auto-guarda um handoff completo antes da próxima resposta (sem perguntar, sem interromper). Aos **95%**, guarda de novo com um aviso urgente.

**Exclusão por sessão** se não quiseres auto-guardado na conversa atual:

```
/handoff-revive:auto off       # desativar SÓ esta sessão
/handoff-revive:auto on        # reativar
/handoff-revive:auto status    # ver estado + limiares
```

`/handoff-revive:auto off` só afeta a sessão atual — uma sessão nova volta a ON. Para desativar o auto-guardado de forma **permanente**, define estas variáveis de ambiente no perfil da tua shell (p. ex. adiciona a `~/.zshrc` ou `~/.bashrc`, e abre um terminal novo):

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

Para mudar os limiares em vez de desativar, define `HANDOFF_AUTO_SAVE_PERCENT=80` (dispara mais cedo) da mesma forma, ou configura-os por hook no `settings.json` (ver [`HOOK_SETUP.md`](HOOK_SETUP.md)).

### Orçamento de tokens

| Método | Tokens reproduzidos ao retomar |
|---|---|
| `claude --resume` | dezenas de milhares, frequentemente 100k+ |
| `claude -c` | dezenas de milhares, frequentemente 100k+ |
| **handoff-revive** | **1.000–3.000** |

### Nos bastidores (automático, zero tokens)

Cada guardado e retoma executa isto em shell puro — sem entrada extra, sem tokens:

- **Metadados de partilha** — cada guardado injeta `author`, `branch`, `base_commit`, `created_at` no frontmatter, para que um colega (ou o teu eu futuro) veja quem guardou, em que ramo e a partir de que commit. `HANDOFF_HIDE_EMAIL=1` omite o email.
- **Verificação de frescura ao retomar** — compara esses metadados com o teu estado git atual e avisa quando o handoff está N commits atrás ou noutro ramo. Também avisa quando o ficheiro é mais antigo que `HANDOFF_STALE_DAYS` (padrão 7; `0` desativa) — a verificação de idade não precisa de git, por isso funciona também em pastas sem git. É puramente informativo; nunca bloqueia a retoma.
- **Histórico de snapshots** — cada guardado arquiva ainda uma cópia em `.claude/handoff/history/<timestamp>.md`. `/handoff-revive:list` mostra-os, `/handoff-revive:restore <timestamp>` recupera um (não destrutivo — o handoff atual é arquivado primeiro), `/handoff-revive:diff [timestamp]` compara. Os snapshots para além de `HANDOFF_HISTORY_RETENTION_DAYS` (padrão 30) são podados automaticamente. Um snapshot é o estado de trabalho estruturado, não o histórico da conversa.

### Relação com CLAUDE.md

Respondem a perguntas diferentes — não escrevas o mesmo nos dois:

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| Contém | conhecimento duradouro do projeto: convenções, arquitetura, comandos | **estado de trabalho volátil**: objetivo atual, WIP, próxima ação |
| Vida | meses (muda raramente) | horas–dias (sobrescrito a cada guardado, com snapshot no histórico) |
| Carregado | todas as sessões, sempre | apenas ao retomar com `/handoff-revive:resume` |

Escrever o estado de trabalho no CLAUDE.md sobrecarrega *todas* as sessões futuras com contexto obsoleto; mantê-lo no handoff não custa nada até realmente retomares. Auxiliar opcional (acrescenta um comentário de uma linha ao CLAUDE.md, idempotente, nunca edita o conteúdo existente):

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-deutsch"></a>
<details>
<summary><b>🇩🇪 Deutsch</b></summary>

<br>

### Das Problem

Wenn Claude Code `You've hit your limit · resets ...` anzeigt, lädt die übliche Wiederherstellung — `claude --resume` oder `-c` — **die gesamte vorherige Konversation** wieder in den Kontext. Eine mittelgroße Sitzung verbraucht zehntausende Tokens, oft 100k+ bei langen Sitzungen, bevor du eine einzige Frage gestellt hast.

### Was dieser Skill tut

Speichert nur das Minimum, das zum Fortsetzen nötig ist, strukturiert in `.claude/handoff/current.md` (~1–3k Tokens):

- **goal** — was du erreichen wolltest
- **done / wip / todo** — erledigt / in Bearbeitung / ausstehend
- **next_action** — konkreter nächster Schritt (`file:line` + exaktes Kommando)
- **touched_files** — bearbeitete Dateien und der Grund
- **decisions** — Design-Entscheidungen **und das Warum**
- **lessons_learned** — gescheiterte Versuche und was sie gelehrt haben (optional)

Zum Fortsetzen startest du eine **neue Sitzung** (KEIN `--resume`). Der Skill liest nur diese eine Datei und setzt fort.

### Installation

**Plugin (empfohlen) — in Claude Code ausführen:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. Marketplace registrieren
/plugin install handoff-revive@handoff-revive-marketplace   # 2. Plugin installieren
```

Skill, Slash-Befehle und Hooks werden automatisch aktiviert. Kein Bearbeiten von `settings.json` nötig.

> Falls `/plugin isn't available in this environment` erscheint, ist deine Claude Code Version zu alt. Prüfe mit `claude --version` und aktualisiere via `brew upgrade claude-code` oder `npm update -g @anthropic-ai/claude-code`.

**Manuelle Installation (funktioniert immer):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# Oder global für alle Projekte:
./install.sh --global       # .\install.ps1 -Global
```

Bei der manuellen Installation kannst du die Hooks optional aktivieren, indem du das Snippet aus [`HOOK_SETUP.md`](HOOK_SETUP.md) in deine `.claude/settings.json` einfügst (die Plugin-Installation erledigt das automatisch).

**Sollte `.claude/handoff/` in git committet werden?** Beides funktioniert — entscheide dich bewusst:

- **Einzelnutzung (Standard)** — alles ignorieren; flüchtiger Zustand und Snapshots gehören nicht in die Historie:
  ```gitignore
  .claude/handoff/
  ```
- **Team-Sharing** — committe nur das aktuelle Handoff; Snapshots und Marker-Dateien bleiben lokal:
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

Committe niemals die Punkt-Marker-Dateien (`.turn`, `.usage-flag`, …) oder `history/` — das ist maschinenlokaler Zustand und Snapshot-Rauschen.

### Benutzung

**Schnellreferenz:**

| Aktion | In Claude Code eingeben |
|---|---|
| Handoff speichern | `/handoff-revive:save` |
| Vorschau dessen, was die nächste Sitzung liest | `/handoff-revive:preview` |
| Gespeicherte Snapshots auflisten | `/handoff-revive:list` |
| Einen früheren Snapshot wiederherstellen | `/handoff-revive:restore <timestamp>` |
| Diff zu einem früheren Snapshot | `/handoff-revive:diff [timestamp]` |
| Handoff als PR-Kommentar teilen | `/handoff-revive:share-to-pr [PR]` (benötigt `gh`) |
| Save/Resume-Statistiken anzeigen | `/handoff-revive:stats` |
| Installation diagnostizieren | `/handoff-revive:doctor` |
| Handoffs beim Branch-Wechsel tauschen | `/handoff-revive:switch` |
| In **neuer Sitzung** fortsetzen | `/handoff-revive:resume` |
| Auto-Save für diese Sitzung umschalten | `/handoff-revive:auto on` / `off` / `status` |

Beim Posten in einen PR wird der Text aus einer **bereinigten Kopie** erstellt: die `author_email`-Zeile wird entfernt, absolute Projekt-/Home-Pfade werden zu `<project-root>` / `~`, und es wird nach API-Schlüsseln/Tokens mit bekannten Präfixen gesucht (z. B. `sk-`, `ghp_`, `AKIA`, Private-Key-Blöcke, JWTs) — wird etwas gefunden, wird das Posten **abgebrochen** (es wird nie stillschweigend geschwärzt). **Die Bereinigung ist Best-Effort, keine Sicherheitsgarantie**: generische Passwörter und zufällige Zeichenketten ohne Präfix werden NICHT erkannt; die Vorschau zu prüfen bleibt deine Verantwortung.

#### Schritt 1 — wenn du dich dem Limit näherst, speichere

Gib in Claude Code den folgenden Befehl ein:

```
/handoff-revive:save
```

Im Hintergrund führt der Skill diese Schritte automatisch aus (nach Möglichkeit ohne Tokens):

1. **Erkennt deine Sprache** (10 Sprachen: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) aus deiner Nachricht
2. **Holt geänderte Dateien aus `git status`** — du musst nicht wissen, welche Dateien du bearbeitet hast
3. **Schreibt ein schemakonformes Handoff** nach `.claude/handoff/current.md`
4. **Validiert das Schema, entfernt tote Pfade und leere Abschnitte** — reine Shell, keine Tokens
5. **Zeigt die geschätzte Ersparnis** im Chat

#### Schritt 2 — warte auf den Limit-Reset

Wenn die Zeit bei `resets ...` verstrichen ist, öffnet sich dein Nutzungsfenster wieder.

#### Schritt 3 — starte eine **neue Sitzung** (NICHT `--resume`)

```bash
claude
```

Wenn die neue Sitzung startet, erkennt das Plugin automatisch das aktuelle Handoff. Führe einfach aus:

```
/handoff-revive:resume
```

Claude liest nur diese eine kleine Datei und macht genau dort weiter, wo du aufgehört hast — ohne die ganze Konversation zu wiederholen.

#### Optional: Erinnerung nach Anzahl der Turns (standardmäßig aus)

Eine periodische Erinnerung zum Checkpointen. Standardmäßig **aus** — aktiviere sie, indem du `HANDOFF_CHECKPOINT_EVERY` auf die Anzahl der Turns zwischen den Erinnerungen setzt (z. B. `15`):

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

Wenn aktiviert, gibt Claude alle N Turns aus:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### Auto-Speichern bei 90% / 95% (synchron mit der UI-Benachrichtigung)

Der `usage-monitor`-Hook (PostToolUse) liest `rate_limits.five_hour.used_percentage` — denselben Wert, der die "Nutzungslimit nähert sich"-Benachrichtigung von Claude Code auslöst. Bei **90%** speichert Claude vor seiner nächsten Antwort automatisch ein vollständiges Handoff (ohne Nachfrage, ohne Unterbrechung). Bei **95%** speichert es erneut mit einem dringenden Hinweis.

**Pro-Sitzung-Opt-out**, falls du im aktuellen Thread kein Auto-Speichern willst:

```
/handoff-revive:auto off       # nur DIESE Sitzung deaktivieren
/handoff-revive:auto on        # wieder aktivieren
/handoff-revive:auto status    # Status + Schwellen anzeigen
```

`/handoff-revive:auto off` betrifft nur die aktuelle Sitzung — eine neue Sitzung ist wieder AN. Um das Auto-Speichern **dauerhaft** abzuschalten, setze diese Umgebungsvariablen in deinem Shell-Profil (z. B. in `~/.zshrc` oder `~/.bashrc` eintragen, dann ein neues Terminal öffnen):

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

Um stattdessen die Schwellen zu verschieben, setze `HANDOFF_AUTO_SAVE_PERCENT=80` (löst früher aus) auf dieselbe Weise, oder konfiguriere sie pro Hook in `settings.json` (siehe [`HOOK_SETUP.md`](HOOK_SETUP.md)).

### Token-Budget

| Methode | Beim Fortsetzen erneut geladene Tokens |
|---|---|
| `claude --resume` | Zehntausende, oft 100k+ |
| `claude -c` | Zehntausende, oft 100k+ |
| **handoff-revive** | **1.000–3.000** |

### Unter der Haube (automatisch, null Tokens)

Jedes Speichern und Fortsetzen führt dies in reiner Shell aus — keine zusätzliche Eingabe, keine Tokens:

- **Sharing-Metadaten** — jedes Speichern injiziert `author`, `branch`, `base_commit`, `created_at` in das Frontmatter, damit ein Teammitglied (oder dein zukünftiges Ich) sieht, wer es gespeichert hat, auf welchem Branch und von welchem Commit. `HANDOFF_HIDE_EMAIL=1` lässt die E-Mail weg.
- **Frische-Prüfung beim Fortsetzen** — vergleicht diese Metadaten mit deinem aktuellen git-Stand und warnt, wenn das Handoff N Commits zurückliegt oder auf einem anderen Branch ist. Es warnt auch, wenn die Datei älter als `HANDOFF_STALE_DAYS` ist (Standard 7; `0` deaktiviert) — die Altersprüfung braucht kein git, funktioniert also auch in einfachen Verzeichnissen. Rein informativ; blockiert das Fortsetzen nie.
- **Snapshot-Historie** — jedes Speichern archiviert zusätzlich eine Kopie nach `.claude/handoff/history/<timestamp>.md`. `/handoff-revive:list` zeigt sie, `/handoff-revive:restore <timestamp>` holt eine zurück (nicht destruktiv — das aktuelle Handoff wird zuerst archiviert), `/handoff-revive:diff [timestamp]` vergleicht. Snapshots jenseits von `HANDOFF_HISTORY_RETENTION_DAYS` (Standard 30) werden automatisch entfernt. Ein Snapshot ist der strukturierte Arbeitszustand, nicht die Konversationshistorie.

### Verhältnis zu CLAUDE.md

Sie beantworten verschiedene Fragen — schreibe nicht dasselbe in beide:

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| Enthält | dauerhaftes Projektwissen: Konventionen, Architektur, Befehle | **flüchtiger Arbeitszustand**: aktuelles Ziel, WIP, nächster Schritt |
| Lebensdauer | Monate (ändert sich selten) | Stunden–Tage (bei jedem Speichern überschrieben, in der Historie gesnapshottet) |
| Geladen | jede Sitzung, immer | nur beim Fortsetzen via `/handoff-revive:resume` |

Arbeitszustand in CLAUDE.md zu schreiben belastet *jede* zukünftige Sitzung mit veraltetem Kontext; im Handoff kostet er nichts, bis du tatsächlich fortsetzt. Optionaler Helfer (fügt CLAUDE.md einen einzeiligen Hinweis-Kommentar hinzu, idempotent, ändert nie vorhandenen Inhalt):

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-français"></a>
<details>
<summary><b>🇫🇷 Français</b></summary>

<br>

### Le problème

Quand Claude Code affiche `You've hit your limit · resets ...`, la récupération habituelle — `claude --resume` ou `-c` — recharge **toute la conversation précédente** dans le contexte. Une session de taille moyenne consomme des dizaines de milliers de tokens, souvent 100k+ pour les sessions longues, avant que vous n'ayez posé une seule question.

### Ce que fait ce skill

Sauvegarde uniquement le minimum nécessaire pour continuer, structuré dans `.claude/handoff/current.md` (~1–3k tokens) :

- **goal** — ce que vous essayiez d'accomplir
- **done / wip / todo** — terminé / en cours / à faire
- **next_action** — prochaine étape exécutable (`file:line` + commande exacte)
- **touched_files** — fichiers modifiés et la raison
- **decisions** — décisions de conception **et le pourquoi**
- **lessons_learned** — tentatives échouées et leurs enseignements (optionnel)

Pour reprendre, lancez une **nouvelle session** (PAS `--resume`). Le skill lit uniquement ce fichier et continue.

### Installation

**Plugin (recommandé) — exécuter dans Claude Code :**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. enregistrer le marketplace
/plugin install handoff-revive@handoff-revive-marketplace   # 2. installer le plugin
```

Skill, commandes slash et hooks s'activent automatiquement. Aucune édition de `settings.json` nécessaire.

> Si `/plugin isn't available in this environment` apparaît, votre version de Claude Code est trop ancienne. Vérifiez avec `claude --version` et mettez à jour via `brew upgrade claude-code` ou `npm update -g @anthropic-ai/claude-code`.

**Installation manuelle (fonctionne toujours) :**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# Ou globalement pour tous les projets :
./install.sh --global       # .\install.ps1 -Global
```

Pour l'installation manuelle, activez éventuellement les hooks en fusionnant l'extrait de [`HOOK_SETUP.md`](HOOK_SETUP.md) dans votre `.claude/settings.json` (l'installation du plugin le fait automatiquement).

**Faut-il committer `.claude/handoff/` dans git ?** Les deux fonctionnent — choisissez délibérément :

- **Usage individuel (par défaut)** — tout ignorer ; l'état volatil et les snapshots n'ont pas leur place dans l'historique :
  ```gitignore
  .claude/handoff/
  ```
- **Partage en équipe** — committez uniquement le handoff actuel ; gardez snapshots et marqueurs en local :
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

Ne committez jamais les fichiers point-marqueur (`.turn`, `.usage-flag`, …) ni `history/` — ce sont des états locaux à la machine et du bruit de snapshots.

### Utilisation

**Référence rapide :**

| Action | Tapez dans Claude Code |
|---|---|
| Sauvegarder le handoff | `/handoff-revive:save` |
| Prévisualiser ce que lira la prochaine session | `/handoff-revive:preview` |
| Lister les snapshots sauvegardés | `/handoff-revive:list` |
| Restaurer un snapshot antérieur | `/handoff-revive:restore <timestamp>` |
| Diff avec un snapshot antérieur | `/handoff-revive:diff [timestamp]` |
| Publier le handoff dans une PR | `/handoff-revive:share-to-pr [PR]` (nécessite `gh`) |
| Voir les statistiques save/resume | `/handoff-revive:stats` |
| Diagnostiquer l'installation | `/handoff-revive:doctor` |
| Permuter les handoffs au changement de branche | `/handoff-revive:switch` |
| Reprendre dans une **NOUVELLE session** | `/handoff-revive:resume` |
| Basculer l'auto-sauvegarde pour cette session | `/handoff-revive:auto on` / `off` / `status` |

Lors de la publication dans une PR, le corps est construit à partir d'une **copie assainie** : la ligne `author_email` est supprimée, les chemins absolus du projet/home deviennent `<project-root>` / `~`, et les clés/tokens d'API à préfixe connu (p. ex. `sk-`, `ghp_`, `AKIA`, blocs de clé privée, JWT) sont recherchés — si l'un est détecté, la publication est **annulée** (rien n'est jamais masqué en silence). **L'assainissement est au mieux, pas une garantie de sécurité** : les mots de passe génériques et les chaînes aléatoires sans préfixe ne sont PAS détectés ; vérifier l'aperçu reste votre responsabilité.

#### Étape 1 — à l'approche de la limite, sauvegardez

Dans Claude Code, tapez la commande suivante :

```
/handoff-revive:save
```

En coulisses, le skill exécute ces étapes automatiquement (sans tokens autant que possible) :

1. **Détecte votre langue** (10 langues : en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) d'après votre message
2. **Récupère les fichiers modifiés depuis `git status`** — pas besoin de vous souvenir de ce que vous avez édité
3. **Écrit un handoff conforme au schema** dans `.claude/handoff/current.md`
4. **Valide le schema, supprime les chemins morts et retire les sections vides** — shell pur, zéro token
5. **Affiche l'économie estimée** dans le chat

#### Étape 2 — attendez la réinitialisation de la limite

Quand l'heure de `resets ...` est passée, votre fenêtre d'usage se rouvre.

#### Étape 3 — démarrez une **nouvelle session** (n'utilisez PAS `--resume`)

```bash
claude
```

Au démarrage de la nouvelle session, le plugin détecte automatiquement le handoff récent. Lancez simplement :

```
/handoff-revive:resume
```

Claude lit uniquement ce petit fichier et reprend exactement où vous vous étiez arrêté — sans rejouer toute la conversation.

#### Optionnel : rappel basé sur le nombre de tours (désactivé par défaut)

Un rappel périodique pour faire un checkpoint. **Désactivé par défaut** — activez-le en réglant `HANDOFF_CHECKPOINT_EVERY` sur le nombre de tours entre rappels (p. ex. `15`) :

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

Une fois activé, tous les N tours Claude affiche :

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### Sauvegarde auto à 90% / 95% (synchronisée avec la notification de l'UI)

Le hook `usage-monitor` (PostToolUse) lit `rate_limits.five_hour.used_percentage` — la même valeur qui déclenche la notification « limite d'usage proche » de Claude Code. À **90%**, Claude sauvegarde automatiquement un handoff complet avant sa réponse suivante (sans demander, sans interrompre). À **95%**, il sauvegarde de nouveau avec un avis urgent.

**Désactivation par session** si vous ne voulez pas d'auto-sauvegarde dans le fil actuel :

```
/handoff-revive:auto off       # désactiver SEULEMENT cette session
/handoff-revive:auto on        # réactiver
/handoff-revive:auto status    # afficher l'état + seuils
```

`/handoff-revive:auto off` n'affecte que la session actuelle — une nouvelle session repasse à ON. Pour désactiver l'auto-sauvegarde **définitivement**, définissez ces variables d'environnement dans le profil de votre shell (p. ex. ajoutez-les à `~/.zshrc` ou `~/.bashrc`, puis ouvrez un nouveau terminal) :

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

Pour décaler les seuils plutôt que désactiver, définissez `HANDOFF_AUTO_SAVE_PERCENT=80` (déclenche plus tôt) de la même façon, ou configurez-les par hook dans `settings.json` (voir [`HOOK_SETUP.md`](HOOK_SETUP.md)).

### Budget de tokens

| Méthode | Tokens rejoués à la reprise |
|---|---|
| `claude --resume` | des dizaines de milliers, souvent 100k+ |
| `claude -c` | des dizaines de milliers, souvent 100k+ |
| **handoff-revive** | **1 000–3 000** |

### Sous le capot (automatique, zéro token)

Chaque sauvegarde et reprise exécute ceci en shell pur — sans entrée supplémentaire, sans tokens :

- **Métadonnées de partage** — chaque sauvegarde injecte `author`, `branch`, `base_commit`, `created_at` dans le frontmatter, pour qu'un coéquipier (ou votre futur vous) voie qui a sauvegardé, sur quelle branche et depuis quel commit. `HANDOFF_HIDE_EMAIL=1` omet l'email.
- **Vérification de fraîcheur à la reprise** — compare ces métadonnées à votre état git actuel et avertit quand le handoff est N commits en retard ou sur une autre branche. Elle avertit aussi quand le fichier est plus ancien que `HANDOFF_STALE_DAYS` (par défaut 7 ; `0` désactive) — la vérification d'âge ne nécessite pas git, elle fonctionne donc aussi dans des dossiers simples. Purement informatif ; ne bloque jamais la reprise.
- **Historique des snapshots** — chaque sauvegarde archive aussi une copie dans `.claude/handoff/history/<timestamp>.md`. `/handoff-revive:list` les liste, `/handoff-revive:restore <timestamp>` en restaure un (non destructif — le handoff actuel est archivé d'abord), `/handoff-revive:diff [timestamp]` compare. Les snapshots au-delà de `HANDOFF_HISTORY_RETENTION_DAYS` (par défaut 30) sont élagués automatiquement. Un snapshot est l'état de travail structuré, pas l'historique de la conversation.

### Relation avec CLAUDE.md

Ils répondent à des questions différentes — n'écrivez pas la même chose dans les deux :

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| Contient | connaissances durables du projet : conventions, architecture, commandes | **état de travail volatil** : objectif actuel, WIP, prochaine action |
| Durée de vie | mois (change rarement) | heures–jours (écrasé à chaque sauvegarde, snapshot dans l'historique) |
| Chargé | chaque session, toujours | uniquement à la reprise via `/handoff-revive:resume` |

Écrire l'état de travail dans CLAUDE.md taxe *chaque* session future avec un contexte obsolète ; le garder dans le handoff ne coûte rien jusqu'à ce que vous repreniez vraiment. Assistant optionnel (ajoute un commentaire d'une ligne à CLAUDE.md, idempotent, ne modifie jamais le contenu existant) :

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-türkçe"></a>
<details>
<summary><b>🇹🇷 Türkçe</b></summary>

<br>

### Sorun

Claude Code `You've hit your limit · resets ...` mesajını gösterdiğinde, olağan kurtarma — `claude --resume` veya `-c` — **tüm önceki konuşmayı** bağlama yeniden yükler. Orta ölçekli bir oturum, tek bir soru sormadan önce on binlerce token, uzun oturumlarda sıklıkla 100k+ tüketir.

### Bu skill ne yapar

Devam etmek için yalnızca gerekli olan minimumu yapılandırılmış olarak `.claude/handoff/current.md` dosyasına kaydeder (~1–3k token):

- **goal** — neyi başarmaya çalıştığınız
- **done / wip / todo** — tamamlandı / devam ediyor / beklemede
- **next_action** — somut sonraki adım (`file:line` + tam komut)
- **touched_files** — dokunulan dosyalar ve nedeni
- **decisions** — tasarım kararları **ve nedenleri**
- **lessons_learned** — başarısız denemeler ve öğrettikleri (isteğe bağlı)

Devam etmek için **yeni bir oturum** başlatın (`--resume` KULLANMAYIN). Skill yalnızca bu dosyayı okur ve devam eder.

### Kurulum

**Plugin (önerilen) — Claude Code içinde çalıştırın:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. marketplace'i kaydet
/plugin install handoff-revive@handoff-revive-marketplace   # 2. plugin'i yükle
```

Skill, slash komutları ve hook'lar otomatik etkinleşir. `settings.json` düzenlemeye gerek yok.

> `/plugin isn't available in this environment` görürseniz, Claude Code sürümünüz çok eski. `claude --version` ile kontrol edin ve `brew upgrade claude-code` veya `npm update -g @anthropic-ai/claude-code` ile güncelleyin.

**Manuel kurulum (her zaman çalışır):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell

# Ya da tüm projeler için global:
./install.sh --global       # .\install.ps1 -Global
```

Manuel kurulumda, [`HOOK_SETUP.md`](HOOK_SETUP.md) içindeki parçacığı `.claude/settings.json` dosyanıza ekleyerek hook'ları isteğe bağlı olarak etkinleştirebilirsiniz (plugin kurulumu bunu otomatik yapar).

**`.claude/handoff/` git'e commit'lenmeli mi?** İkisi de çalışır — bilinçli olarak birini seçin:

- **Bireysel kullanım (varsayılan)** — hepsini yok say; geçici durum ve anlık görüntüler geçmişe ait değildir:
  ```gitignore
  .claude/handoff/
  ```
- **Takımla paylaşım** — yalnızca mevcut handoff'u commit'leyin; anlık görüntüleri ve işaret dosyalarını yerel tutun:
  ```gitignore
  .claude/handoff/*
  !.claude/handoff/current.md
  ```

Nokta-işaret dosyalarını (`.turn`, `.usage-flag`, …) veya `history/` dizinini asla commit'lemeyin — bunlar makineye özgü durum ve anlık görüntü gürültüsüdür.

### Kullanım

**Hızlı referans:**

| Eylem | Claude Code'a yazın |
|---|---|
| Handoff kaydet | `/handoff-revive:save` |
| Sonraki oturumun okuyacağını önizle | `/handoff-revive:preview` |
| Kayıtlı anlık görüntüleri listele | `/handoff-revive:list` |
| Geçmiş bir anlık görüntüyü geri yükle | `/handoff-revive:restore <timestamp>` |
| Geçmiş anlık görüntüyle fark | `/handoff-revive:diff [timestamp]` |
| Handoff'u PR yorumu olarak paylaş | `/handoff-revive:share-to-pr [PR]` (`gh` gerekir) |
| Kaydet/devam istatistiklerini göster | `/handoff-revive:stats` |
| Kurulumu tanıla | `/handoff-revive:doctor` |
| Dal değişiminde handoff değiştir | `/handoff-revive:switch` |
| **YENİ oturumda** devam et | `/handoff-revive:resume` |
| Bu oturum için otomatik kaydı değiştir | `/handoff-revive:auto on` / `off` / `status` |

Bir PR'a gönderirken gövde, **temizlenmiş bir kopyadan** oluşturulur: `author_email` satırı kaldırılır, mutlak proje/ev dizini yolları `<project-root>` / `~` olur ve bilinen önekli API anahtarları/token'ları (örn. `sk-`, `ghp_`, `AKIA`, özel anahtar blokları, JWT) taranır — biri tespit edilirse gönderim **iptal edilir** (hiçbir şey sessizce sansürlenmez). **Temizleme en iyi çabadır, güvenlik garantisi değildir**: genel parolalar ve öneksiz rastgele dizeler tespit EDİLMEZ; önizlemeyi gözden geçirmek sizin sorumluluğunuzdadır.

#### Adım 1 — sınıra yaklaşırken kaydet

Claude Code'a şu komutu yazın:

```
/handoff-revive:save
```

Arka planda skill şu adımları otomatik çalıştırır (mümkün olduğunca sıfır token):

1. **Dilinizi algılar** (10 dil: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) — mesajınızdan
2. **`git status`'ten değişen dosyaları çeker** — hangi dosyaları düzenlediğinizi hatırlamanız gerekmez
3. **Şemaya uygun bir handoff yazar** `.claude/handoff/current.md` dosyasına
4. **Şemayı doğrular, ölü yolları siler, boş bölümleri kaldırır** — saf shell, sıfır token
5. **Tahmini tasarrufu** sohbette gösterir

#### Adım 2 — limit sıfırlanmasını bekleyin

`resets ...` zamanı geçtiğinde kullanım pencereniz yeniden açılır.

#### Adım 3 — **yeni bir oturum** başlatın (`--resume` KULLANMAYIN)

```bash
claude
```

Yeni oturum başladığında plugin son handoff'u otomatik algılar. Sadece şunu çalıştırın:

```
/handoff-revive:resume
```

Claude yalnızca o küçük dosyayı okur ve kaldığınız yerden devam eder — tüm konuşmayı yeniden oynatmaya gerek yok.

#### İsteğe bağlı: tur sayısına göre hatırlatma (varsayılan kapalı)

Düzenli bir checkpoint hatırlatması. **Varsayılan olarak kapalı** — `HANDOFF_CHECKPOINT_EVERY` değerini hatırlatmalar arasındaki tur sayısına ayarlayarak etkinleştirin (örn. `15`):

```sh
export HANDOFF_CHECKPOINT_EVERY=15
```

Etkinleştirildiğinde Claude her N turda şunu yazar:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff-revive:save to save.
```

#### %90 / %95'te otomatik kayıt (UI bildirimiyle eşzamanlı)

`usage-monitor` hook'u (PostToolUse) `rate_limits.five_hour.used_percentage` değerini okur — Claude Code'un "kullanım limitine yaklaşıyorsun" bildirimini tetikleyen değerin aynısı. **%90**'a ulaşıldığında Claude bir sonraki yanıtından önce tam bir handoff'u otomatik kaydeder (sormadan, kesintisiz). **%95**'te acil bir uyarıyla tekrar kaydeder.

**Mevcut akışta otomatik kayıt istemiyorsanız oturum bazında devre dışı bırakma:**

```
/handoff-revive:auto off       # SADECE bu oturumu devre dışı bırak
/handoff-revive:auto on        # yeniden etkinleştir
/handoff-revive:auto status    # durum + eşikleri göster
```

`/handoff-revive:auto off` yalnızca mevcut oturumu etkiler — yeni bir oturum yeniden AÇIK olur. Otomatik kaydı **kalıcı olarak** kapatmak için bu ortam değişkenlerini shell profilinize ekleyin (örn. `~/.zshrc` veya `~/.bashrc`'ye ekleyip yeni bir terminal açın):

```sh
export HANDOFF_AUTO_SAVE_PERCENT=disabled
export HANDOFF_URGENT_PERCENT=disabled
```

Devre dışı bırakmak yerine eşikleri kaydırmak için aynı şekilde `HANDOFF_AUTO_SAVE_PERCENT=80` (daha erken tetiklenir) ayarlayın veya `settings.json` içinde hook bazında yapılandırın (bkz. [`HOOK_SETUP.md`](HOOK_SETUP.md)).

### Token bütçesi

| Yöntem | Devam ederken yeniden oynatılan token |
|---|---|
| `claude --resume` | on binlerce, sıklıkla 100k+ |
| `claude -c` | on binlerce, sıklıkla 100k+ |
| **handoff-revive** | **1.000–3.000** |

### Kaputun altında (otomatik, sıfır token)

Her kayıt ve devam, bunu saf shell ile çalıştırır — ek girdi yok, token yok:

- **Paylaşım meta verileri** — her kayıt `author`, `branch`, `base_commit`, `created_at` değerlerini frontmatter'a enjekte eder; böylece bir takım arkadaşı (ya da gelecekteki siz) kimin, hangi dalda, hangi commit'ten kaydettiğini görebilir. `HANDOFF_HIDE_EMAIL=1` e-postayı atlar.
- **Devamda tazelik kontrolü** — bu meta verileri mevcut git durumunuzla karşılaştırır ve handoff N commit geride ya da farklı bir daldaysa uyarır. Dosya `HANDOFF_STALE_DAYS`'ten (varsayılan 7; `0` kapatır) eskiyse de uyarır — yaş kontrolü git gerektirmez, bu yüzden düz dizinlerde de çalışır. Tamamen bilgilendirme amaçlıdır; devam etmeyi asla engellemez.
- **Anlık görüntü geçmişi** — her kayıt ayrıca bir kopyayı `.claude/handoff/history/<timestamp>.md` dosyasına arşivler. `/handoff-revive:list` bunları gösterir, `/handoff-revive:restore <timestamp>` birini geri getirir (yıkıcı değil — mevcut handoff önce arşivlenir), `/handoff-revive:diff [timestamp]` karşılaştırır. `HANDOFF_HISTORY_RETENTION_DAYS`'i (varsayılan 30) aşan anlık görüntüler otomatik temizlenir. Bir anlık görüntü, konuşma geçmişi değil, yapılandırılmış çalışma durumudur.

### CLAUDE.md ile ilişkisi

Farklı soruları yanıtlarlar — aynı şeyi ikisine de yazmayın:

| | CLAUDE.md | handoff (`current.md`) |
|---|---|---|
| İçerir | kalıcı proje bilgisi: kurallar, mimari, komutlar | **geçici çalışma durumu**: mevcut hedef, WIP, sonraki adım |
| Ömür | aylar (nadiren değişir) | saatler–günler (her kayıtta üzerine yazılır, geçmişe anlık görüntü) |
| Yüklenir | her oturum, her zaman | yalnızca `/handoff-revive:resume` ile devam ederken |

Çalışma durumunu CLAUDE.md'ye yazmak, *gelecekteki her* oturumu eski bağlamla yükler; handoff'ta tutmak, gerçekten devam edene kadar hiçbir maliyet getirmez. İsteğe bağlı yardımcı (CLAUDE.md'ye tek satırlık bir rehber yorum ekler, idempotent, mevcut içeriği asla değiştirmez):

```sh
bash .claude/skills/handoff-revive/scripts/setup-claude-md.sh
```

### License

MIT — see [LICENSE](LICENSE).

</details>


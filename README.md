<h1 align="center">claude-handoff-revive</h1>

<p align="center">
  <a href="https://github.com/sofumel/claude-handoff-revive/actions/workflows/ci.yml"><img src="https://github.com/sofumel/claude-handoff-revive/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/sofumel/claude-handoff-revive/releases"><img src="https://img.shields.io/github/v/release/sofumel/claude-handoff-revive" alt="Release"></a>
  <a href="https://github.com/sofumel/claude-handoff-revive/stargazers"><img src="https://img.shields.io/github/stars/sofumel/claude-handoff-revive?style=flat" alt="Stars"></a>
  <a href="https://github.com/sofumel/claude-handoff-revive/graphs/contributors"><img src="https://img.shields.io/github/contributors/sofumel/claude-handoff-revive" alt="Contributors"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/sofumel/claude-handoff-revive" alt="License: MIT"></a>
  <a href="#claude-handoff-revive"><img src="https://img.shields.io/badge/lang-en%20%7C%20ja%20%7C%20zh%20%7C%20zh--TW%20%7C%20ko%20%7C%20es%20%7C%20pt%20%7C%20de%20%7C%20fr%20%7C%20tr-blue" alt="Multi-language"></a>
</p>

<p align="center">
  <em>Continue Claude Code work after a rate / usage / context limit <strong>without</strong> burning 30k–200k tokens replaying the prior transcript.</em>
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

---

<a id="-english"></a>
<details open>
<summary><b>🇺🇸 English</b></summary>

<br>

### The problem

When Claude Code shows `You've hit your limit · resets ...`, the standard recovery — `claude --resume` or `claude -c` — reloads **the entire prior conversation** into context. A medium session typically burns 30,000–200,000 tokens before you've asked a single question.

### What this skill does

It saves only the minimum needed to continue, structured into `.claude/handoff/current.md` (~1–3k tokens):

- **goal** — what you were trying to accomplish
- **done / wip / todo** — completed, in-progress, not-yet-started tasks
- **next_action** — the concrete next step (`file:line` + exact command)
- **touched_files** — what files were touched and why
- **decisions** — design choices, with the *reason* behind each

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

### How to use

**Quick reference:**

| Action | Type this in Claude Code |
|---|---|
| Save handoff | `/handoff` |
| Save with extra quality check | `/handoff --verify` |
| Resume in a NEW session | `/resume-from-handoff` |
| Toggle auto-save for this session | `/handoff-auto on` / `off` / `status` |

#### Step 1 — when you're approaching a rate limit, save

In Claude Code, type the following command:

```
/handoff
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

When the new session starts:

- The SessionStart hook detects `.claude/handoff/current.md` (if modified within the last 7 days)
- It injects context for Claude: *"A recent handoff exists — prefer it over `--resume`"*
- You run `/resume-from-handoff` and Claude reads only the handoff file and continues

#### Step 4 — (optional) higher-quality saves

```
/handoff --verify
```

After the regular save, Claude runs an extra **semantic-quality check**:

- Is `goal` specific enough that someone with no context understands it?
- Does each `decision` include a real *reason*, not just the decision restated?
- Are `blockers` phrased as answerable questions?
- Does `wip` describe state precisely enough to resume mid-edit?

Vague fields get rewritten automatically.

#### Optional: turn-count nudge

If the Stop hook is enabled, Claude reminds you to checkpoint every N turns (default 15):

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff to save.
```

Plugin install activates this automatically; manual install — see [`HOOK_SETUP.md`](HOOK_SETUP.md). Override the threshold with `HANDOFF_CHECKPOINT_EVERY=10`.

#### Auto-save at 90% / 95% usage (synced with the UI notification)

The `usage-monitor` hook (PostToolUse) reads `rate_limits.five_hour.used_percentage` — the same value that drives Claude Code's "approaching usage limit" notification. When you cross **90%**, Claude auto-saves a full handoff before its next response (no asking, no interruption). At **95%**, it saves again with an urgent notice.

**Per-session opt-out** if you don't want auto-save in the current thread:

```
/handoff-auto off       # disable for THIS session
/handoff-auto on        # re-enable
/handoff-auto status    # show current state + thresholds
```

New Claude sessions reset to enabled. To disable globally: `export HANDOFF_AUTO_SAVE_PERCENT=disabled HANDOFF_URGENT_PERCENT=disabled`.

To shift thresholds: `export HANDOFF_AUTO_SAVE_PERCENT=80` (earlier), or set per-hook in `settings.json` (see [`HOOK_SETUP.md`](HOOK_SETUP.md)).

### Token budget

| Method | Tokens to start a fresh session |
|---|---|
| `claude --resume` | 30,000–200,000 |
| `claude -c` | 30,000–200,000 |
| **handoff-revive** | **1,000–3,000** |

**You break even after just one save and one resume.**
Even in the worst case where you save and never resume, the overhead is only a few KB — costs never run away.

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-日本語"></a>
<details>
<summary><b>🇯🇵 日本語</b></summary>

<br>

### 解決する問題

`You've hit your limit · resets ...` という制限通知が表示された後、`claude --resume` や `-c` で再開すると、**それまでの会話履歴がまるごと**コンテキストに再ロードされます。中規模のセッションでも 30,000〜200,000 トークン分が、まだ何も質問していない段階で消費されてしまいます。

### この skill が提供するもの

作業の続きに必要な最小限の情報だけを構造化して `.claude/handoff/current.md` に保存します（約 1〜3k トークン）。保存される項目:

- **goal** — 何を達成しようとしていたか
- **done / wip / todo** — 完了済み / 進行中 / 未着手のタスク
- **next_action** — 実行可能な次の一手（`file:line` + 具体的なコマンド）
- **touched_files** — 触ったファイルとその理由
- **decisions** — 設計判断と、その**根拠**

再開時は `claude --resume` を使わず **新規セッション**を起動するだけ。skill がこの 1 ファイルだけを読み込み、即座に作業を引き継ぎます。

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

マニュアルインストールの場合のみ、[`HOOK_SETUP.md`](HOOK_SETUP.md) のスニペットを `.claude/settings.json` にマージして hooks を有効化してください (プラグインインストールでは自動)。

### 使い方

**早見表:**

| やりたいこと | Claude Code に入力するコマンド |
|---|---|
| ハンドオフを保存 | `/handoff` |
| 品質チェック付きで保存 | `/handoff --verify` |
| **新規セッション** で再開 | `/resume-from-handoff` |
| このセッションの自動保存を切り替え | `/handoff-auto on` / `off` / `status` |

#### ステップ 1 — レート制限が近づいたら保存する

Claude Code で、以下のコマンドを入力してください:

```
/handoff
```

裏では skill が以下を自動実行します（できる限りトークンを使わずに）:

1. **言語を検出** (10 言語対応: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr) — あなたのメッセージから判定
2. **`git status` から変更ファイルを抽出** — どのファイルを編集したか思い出す必要なし
3. **スキーマ通りのハンドオフを `.claude/handoff/current.md` に書き込み**
4. **スキーマ検証 + 無効パスエントリの自動削除 + 空セクションの除去** — すべて純シェル (Claude を呼ばずシェルスクリプトだけで処理) なので **LLM トークンを消費しません**
5. **節約見込みをチャットに表示**

#### ステップ 2 — レート制限の解除を待つ

`resets ...` の時刻を過ぎたら、使用枠が回復します。

#### ステップ 3 — **新規セッション**を起動 (`--resume` は使わない)

```bash
claude
```

新セッションが起動すると:

- SessionStart hook が `.claude/handoff/current.md` (7 日以内に更新) を検出
- Claude にコンテキスト注入: 「最近のハンドオフがあります。`--resume` ではなくこちらを優先してください」
- あなたが `/resume-from-handoff` を実行すると、Claude がハンドオフファイルだけを読んで作業再開

#### ステップ 4 — (任意) 保存品質を強化したい場合

```
/handoff --verify
```

通常の保存後に、Claude による追加の**意味的チェック**が走ります:

- `goal` が具体的かどうか (「認証バグを直す」のような曖昧さでなく「login.ts の bcrypt.compare をタイミング攻撃に強い実装に置換」のような具体性)
- 各 `decision` に **根拠**が書いてあるか (決定の言い換えではなく "WHY" が明示されているか)
- `blockers` が「答えられる質問形式」になっているか
- `wip` が「再開時に作業位置が分かる粒度」になっているか

不十分なフィールドを Claude が自動的に書き直します。

#### 任意機能: ターン数 nudge

Stop hook を有効化すると、ターン数が指定値（デフォルト 15）を超えるたびにリマインドが出ます:

```
[handoff-revive] Turn 15 — checkpoint due. Run /handoff to save.
```

プラグインインストールでは自動有効化されます。マニュアルインストールの場合は [`HOOK_SETUP.md`](HOOK_SETUP.md) を参照。閾値は環境変数 `HANDOFF_CHECKPOINT_EVERY=10` で変更可能。

#### 90% / 95% 到達で自動保存 (UI 通知と同期)

`usage-monitor` hook (PostToolUse) が `rate_limits.five_hour.used_percentage` を読み取ります — Claude Code の「使用量の上限に近づいています」通知を駆動するのと**同じ値**です。**90%** 到達時、Claude が次の応答前にフルクオリティのハンドオフを自動保存します (確認なし、作業中断なし)。**95%** に達すると、緊急通知付きで再度自動保存されます。

**このセッションの自動保存をオフにしたい場合:**

```
/handoff-auto off       # このセッションのみ無効化
/handoff-auto on        # 再有効化
/handoff-auto status    # 現在の状態 + 閾値を表示
```

新しい Claude セッションを起動すると自動保存はデフォルト ON に戻ります。グローバルに無効化するには: `export HANDOFF_AUTO_SAVE_PERCENT=disabled HANDOFF_URGENT_PERCENT=disabled`。

閾値変更: `export HANDOFF_AUTO_SAVE_PERCENT=80` (より早めに発火)、または `settings.json` の hook で個別指定 ([`HOOK_SETUP.md`](HOOK_SETUP.md) 参照)。

### トークン収支

| 方式 | 新セッション開始時のトークン |
|---|---|
| `claude --resume` | 30,000〜200,000 |
| `claude -c` | 30,000〜200,000 |
| **handoff-revive** | **1,000〜3,000** |

**1 回保存して 1 回再開すれば、必ず黒字です。**
たとえ保存だけで一度も再開しない場合でも、発生するのは数 KB 程度のオーバーヘッドだけで、コストが暴走することはありません。

### ライセンス

MIT — [LICENSE](LICENSE) 参照。

</details>

---

<a id="-中文"></a>
<details>
<summary><b>🇨🇳 中文</b></summary>

<br>

### 要解决的问题

当 Claude Code 显示 `You've hit your limit · resets ...` 时，使用 `claude --resume` 或 `claude -c` 恢复会把**之前的整个会话**重新载入上下文。中等规模会话通常需要 30,000–200,000 tokens——还没问一个问题就已经用掉了。

### 此 skill 提供什么

把恢复所需的**最少信息**以结构化方式保存到 `.claude/handoff/current.md`（约 1–3k tokens）：

- **goal** — 你想完成什么
- **done / wip / todo** — 完成 / 进行中 / 待办
- **next_action** — 可执行的下一步（`file:line` + 具体命令）
- **touched_files** — 涉及的文件及其原因
- **decisions** — 设计决策**及其理由**

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
```

手动安装时可选：将 [`HOOK_SETUP.md`](HOOK_SETUP.md) 中的代码片段合并到 `.claude/settings.json` 启用 hooks (插件安装会自动完成)。

### 使用方法

**快速参考:**

| 操作 | 在 Claude Code 输入 |
|---|---|
| 保存 handoff | `/handoff` |
| 带质量检查的保存 | `/handoff --verify` |
| **新会话**中恢复 | `/resume-from-handoff` |
| 切换本会话的自动保存 | `/handoff-auto on` / `off` / `status` |

#### 步骤 1 — 接近速率限制时保存

```
/handoff
```

skill 自动执行（尽量零 token）:

1. **检测语言** (10 种语言: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr)
2. **从 `git status` 提取变更文件** — 不用回忆改了哪些文件
3. **按 schema 写入 `.claude/handoff/current.md`**
4. **schema 验证 + 死路径删除 + 空段落删除** — 纯 shell，零 token
5. **在聊天中显示节省估算**

#### 步骤 2 — 等待限制重置

到达 `resets ...` 时间后，使用额度恢复。

#### 步骤 3 — 启动**新会话** (不要用 `--resume`)

```bash
claude
```

新会话启动时:

- SessionStart hook 检测 `.claude/handoff/current.md` (7 天以内)
- 注入上下文: "存在最近的 handoff，优先使用而不是 `--resume`"
- 你运行 `/resume-from-handoff` — Claude 只读 handoff 文件即可恢复

#### 步骤 4 — (可选) 提高保存质量

```
/handoff --verify
```

常规保存后再追加 Claude 的**语义检查**:
- goal 是否具体？
- 各 decision 是否包含真实理由？
- blockers 是否为可回答的问题？
- wip 是否精确到能从中间恢复？

#### 90% / 95% 自动保存 (与 UI 通知同步)

`usage-monitor` hook 读取 `rate_limits.five_hour.used_percentage` —— 这与 Claude Code "接近使用上限" 通知所用的值相同。**90%** 时 Claude 在下次回复前自动完整保存 handoff (无需询问、不打断)。**95%** 时再次保存并附紧急通知。

**本会话不需要自动保存时:**

```
/handoff-auto off       # 仅本会话禁用
/handoff-auto on        # 重新启用
/handoff-auto status    # 查看状态 + 阈值
```

新会话默认启用。全局禁用: `export HANDOFF_AUTO_SAVE_PERCENT=disabled HANDOFF_URGENT_PERCENT=disabled`。

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-繁體中文"></a>
<details>
<summary><b>🇹🇼 繁體中文</b></summary>

<br>

### 要解決的問題

當 Claude Code 顯示 `You've hit your limit · resets ...` 時，使用 `claude --resume` 或 `claude -c` 恢復會把**之前的整個會話**重新載入上下文。中等規模會話通常需要 30,000–200,000 tokens——還沒問一個問題就已經用掉了。

### 此 skill 提供什麼

把恢復所需的**最少資訊**以結構化方式儲存到 `.claude/handoff/current.md`（約 1–3k tokens）：

- **goal** — 你想完成什麼
- **done / wip / todo** — 完成 / 進行中 / 待辦
- **next_action** — 可執行的下一步（`file:line` + 具體命令）
- **touched_files** — 涉及的檔案及其原因
- **decisions** — 設計決策**及其理由**

恢復時啟動**新會話**（不要用 `--resume`）。skill 只讀取這一個檔案即可繼續工作。

### 安裝

**外掛程式安裝 (推薦) — 在 Claude Code 內執行:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. 註冊 marketplace
/plugin install handoff-revive@handoff-revive-marketplace   # 2. 安裝外掛
```

> 如果出現 `/plugin isn't available in this environment`，說明 Claude Code 版本過舊。執行 `claude --version` 確認，並透過 `brew upgrade claude-code` 或 `npm update -g @anthropic-ai/claude-code` 升級。

**手動安裝 (始終可用):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell
```

### 使用方式

| 操作 | 在 Claude Code 輸入 |
|---|---|
| 儲存 handoff | `/handoff` |
| 帶品質檢查的儲存 | `/handoff --verify` |
| **新會話**中恢復 | `/resume-from-handoff` |
| 切換本會話的自動儲存 | `/handoff-auto on` / `off` / `status` |

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-한국어"></a>
<details>
<summary><b>🇰🇷 한국어</b></summary>

<br>

### 해결하는 문제

`You've hit your limit · resets ...` 메시지가 나타난 뒤 `claude --resume` 또는 `-c` 로 재개하면 **이전 세션 전체** 가 컨텍스트로 다시 로드됩니다. 중간 규모 세션이라면 30,000–200,000 tokens 가 아무 질문하기도 전에 사라집니다.

### 이 skill 이 제공하는 것

작업 재개에 필요한 최소 정보만을 구조화하여 `.claude/handoff/current.md` 에 저장합니다(약 1–3k tokens):

- **goal** — 무엇을 달성하려 했는가
- **done / wip / todo** — 완료 / 진행 중 / 대기
- **next_action** — 실행 가능한 다음 단계 (`file:line` + 구체적 명령)
- **touched_files** — 다룬 파일과 그 이유
- **decisions** — 설계 결정과 **근거**

재개할 때는 `--resume` 을 쓰지 말고 **새 세션**을 시작합니다. skill 이 그 파일 하나만 읽고 즉시 작업을 이어갑니다.

### 설치

**플러그인 설치 (권장) — Claude Code 안에서 실행:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. 마켓플레이스 등록
/plugin install handoff-revive@handoff-revive-marketplace   # 2. 플러그인 설치
```

> `/plugin isn't available in this environment` 메시지가 나오면 Claude Code 버전이 오래되었습니다. `claude --version` 으로 확인하고 `brew upgrade claude-code` 또는 `npm update -g @anthropic-ai/claude-code` 로 업데이트하세요.

**수동 설치 (항상 동작):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell
```

### 사용법

**빠른 참조:**

| 작업 | Claude Code 입력 |
|---|---|
| 핸드오프 저장 | `/handoff` |
| 품질 검사 포함 저장 | `/handoff --verify` |
| **새 세션** 에서 재개 | `/resume-from-handoff` |
| 이 세션 자동 저장 토글 | `/handoff-auto on` / `off` / `status` |

#### 단계 1 — 사용량 한도가 가까워지면 저장

```
/handoff
```

skill 이 자동으로 (가능한 한 0 토큰으로):

1. **언어 감지** (10개 언어 지원: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr)
2. **`git status` 에서 변경 파일 추출**
3. **스키마대로 `.claude/handoff/current.md` 에 저장**
4. **스키마 검증 + 죽은 경로 제거 + 빈 섹션 제거** — 순 shell, 0 토큰
5. **절약량 표시**

#### 단계 2 — 한도 리셋 대기

`resets ...` 시간이 지나면 사용량이 복구됩니다.

#### 단계 3 — **새 세션** 시작 (`--resume` 사용 금지)

```bash
claude
```

새 세션 시작 시:
- SessionStart hook 이 `.claude/handoff/current.md` 감지 (7일 이내)
- 컨텍스트 주입: "최근 핸드오프 존재 — `--resume` 대신 이걸 사용"
- `/resume-from-handoff` 를 실행하면 Claude 가 핸드오프만 읽고 재개

#### 단계 4 — (선택) 더 높은 품질의 저장

```
/handoff --verify
```

추가로 Claude 의 **의미적 검증** 실행: goal 이 구체적인지, 각 decision 에 진짜 이유가 있는지 등.

#### 90% / 95% 자동 저장 (UI 알림과 동기)

`usage-monitor` hook 이 `rate_limits.five_hour.used_percentage` 를 읽음 — Claude Code 의 "사용량 한도 접근" 알림과 같은 값. **90%** 도달 시 Claude 가 다음 응답 전에 풀 핸드오프를 자동 저장 (질문 없이, 중단 없이). **95%** 에서 긴급 알림과 함께 재저장.

**이 세션에서 자동 저장 끄기:**

```
/handoff-auto off       # 이 세션만 비활성화
/handoff-auto on        # 다시 활성화
/handoff-auto status    # 상태 + 임계값 확인
```

새 세션은 기본 활성화. 전역 비활성화: `export HANDOFF_AUTO_SAVE_PERCENT=disabled HANDOFF_URGENT_PERCENT=disabled`.

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-español"></a>
<details>
<summary><b>🇪🇸 Español</b></summary>

<br>

### El problema

Cuando Claude Code muestra `You've hit your limit · resets ...`, la recuperación habitual — `claude --resume` o `-c` — recarga **toda la conversación anterior** en el contexto. Una sesión mediana son 30,000–200,000 tokens gastados antes de hacer una sola pregunta.

### Lo que ofrece este skill

Guarda solo el mínimo necesario para continuar, estructurado en `.claude/handoff/current.md` (~1–3k tokens):

- **goal** — qué intentabas lograr
- **done / wip / todo** — completado / en progreso / pendiente
- **next_action** — siguiente paso ejecutable (`file:line` + comando exacto)
- **touched_files** — archivos tocados y su razón
- **decisions** — decisiones de diseño y **el por qué**

Para reanudar, inicia una **sesión nueva** (NO uses `--resume`). El skill lee solo ese archivo y continúa.

### Instalación

**Plugin (recomendado) — ejecutar dentro de Claude Code:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. registrar marketplace
/plugin install handoff-revive@handoff-revive-marketplace   # 2. instalar plugin
```

> Si aparece `/plugin isn't available in this environment`, tu versión de Claude Code es antigua. Verifica con `claude --version` y actualiza con `brew upgrade claude-code` o `npm update -g @anthropic-ai/claude-code`.

**Instalación manual (siempre funciona):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell
```

### Cómo usar

**Referencia rápida:**

| Acción | Escribe en Claude Code |
|---|---|
| Guardar handoff | `/handoff` |
| Guardar con verificación | `/handoff --verify` |
| Reanudar en una **sesión nueva** | `/resume-from-handoff` |
| Alternar auto-guardado en esta sesión | `/handoff-auto on` / `off` / `status` |

#### Paso 1 — al acercarte al límite, guarda

```
/handoff
```

El skill ejecuta automáticamente (con cero tokens cuando es posible):

1. **Detecta tu idioma** (10 idiomas: en / ja / zh / zh-TW / ko / es / pt / de / fr / tr)
2. **Extrae archivos modificados de `git status`**
3. **Escribe el handoff conforme al schema** en `.claude/handoff/current.md`
4. **Valida schema + elimina rutas muertas + elimina secciones vacías** — solo shell, cero tokens
5. **Muestra el ahorro estimado**

#### Paso 2 — espera al reset

Cuando pase la hora indicada en `resets ...`, tu cuota se restablece.

#### Paso 3 — inicia una **sesión nueva** (NO uses `--resume`)

```bash
claude
```

Al iniciar:
- El hook SessionStart detecta `.claude/handoff/current.md` (modificado en últimos 7 días)
- Inyecta contexto: "Existe handoff reciente — prefiérelo sobre `--resume`"
- Ejecuta `/resume-from-handoff` — Claude lee solo el handoff y continúa

#### Paso 4 — (opcional) guardado de mayor calidad

```
/handoff --verify
```

Tras el guardado normal, Claude ejecuta una **verificación semántica**: ¿es `goal` específico? ¿incluye cada `decision` una razón real?

#### Auto-guardado al 90% / 95% (sincronizado con la notificación de UI)

El hook `usage-monitor` lee `rate_limits.five_hour.used_percentage` — el mismo valor que dispara la notificación "uso cerca del límite" de Claude Code. Al **90%** Claude auto-guarda un handoff completo antes de su siguiente respuesta (sin preguntar, sin interrumpir). Al **95%** vuelve a guardar con aviso urgente.

**Para desactivar el auto-guardado en esta sesión:**

```
/handoff-auto off       # desactivar SOLO esta sesión
/handoff-auto on        # reactivar
/handoff-auto status    # ver estado + umbrales
```

Las sesiones nuevas vuelven al estado activado. Desactivación global: `export HANDOFF_AUTO_SAVE_PERCENT=disabled HANDOFF_URGENT_PERCENT=disabled`.

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-português"></a>
<details>
<summary><b>🇵🇹 Português</b></summary>

<br>

### O problema

Quando o Claude Code mostra `You've hit your limit · resets ...`, a recuperação habitual — `claude --resume` ou `-c` — recarrega **toda a conversa anterior** no contexto. Uma sessão média gasta 30,000–200,000 tokens antes de fazer uma única pergunta.

### O que esta skill faz

Guarda apenas o mínimo necessário para continuar, estruturado em `.claude/handoff/current.md` (~1–3k tokens):

- **goal** — o que estavas a tentar alcançar
- **done / wip / todo** — concluído / em curso / pendente
- **next_action** — próximo passo executável (`file:line` + comando exato)
- **touched_files** — ficheiros tocados e a razão
- **decisions** — decisões de design **e o porquê**

Para retomar, inicia uma **sessão nova** (NÃO uses `--resume`). A skill lê apenas esse ficheiro e continua.

### Instalação

**Plugin (recomendado) — executar dentro do Claude Code:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. registar marketplace
/plugin install handoff-revive@handoff-revive-marketplace   # 2. instalar plugin
```

> Se aparecer `/plugin isn't available in this environment`, a tua versão do Claude Code é antiga. Verifica com `claude --version` e atualiza via `brew upgrade claude-code` ou `npm update -g @anthropic-ai/claude-code`.

**Instalação manual (sempre funciona):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell
```

### Uso

| Ação | Escreve no Claude Code |
|---|---|
| Guardar handoff | `/handoff` |
| Guardar com verificação | `/handoff --verify` |
| Retomar numa **sessão nova** | `/resume-from-handoff` |
| Alternar auto-save nesta sessão | `/handoff-auto on` / `off` / `status` |

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-deutsch"></a>
<details>
<summary><b>🇩🇪 Deutsch</b></summary>

<br>

### Das Problem

Wenn Claude Code `You've hit your limit · resets ...` anzeigt, lädt die übliche Wiederherstellung — `claude --resume` oder `-c` — **die gesamte vorherige Konversation** wieder in den Kontext. Eine mittelgroße Sitzung verbraucht 30,000–200,000 Tokens, bevor du eine einzige Frage gestellt hast.

### Was dieser Skill tut

Speichert nur das Minimum, das zum Fortsetzen nötig ist, strukturiert in `.claude/handoff/current.md` (~1–3k Tokens):

- **goal** — was du erreichen wolltest
- **done / wip / todo** — erledigt / in Bearbeitung / ausstehend
- **next_action** — konkreter nächster Schritt (`file:line` + exaktes Kommando)
- **touched_files** — bearbeitete Dateien und der Grund
- **decisions** — Design-Entscheidungen **und das Warum**

Zum Fortsetzen startest du eine **neue Sitzung** (KEIN `--resume`). Der Skill liest nur diese eine Datei und setzt fort.

### Installation

**Plugin (empfohlen) — in Claude Code ausführen:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. Marketplace registrieren
/plugin install handoff-revive@handoff-revive-marketplace   # 2. Plugin installieren
```

> Falls `/plugin isn't available in this environment` erscheint, ist deine Claude Code Version zu alt. Prüfe mit `claude --version` und aktualisiere via `brew upgrade claude-code` oder `npm update -g @anthropic-ai/claude-code`.

**Manuelle Installation (funktioniert immer):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell
```

### Benutzung

| Aktion | In Claude Code eingeben |
|---|---|
| Handoff speichern | `/handoff` |
| Mit Qualitätsprüfung speichern | `/handoff --verify` |
| In **neuer Sitzung** fortsetzen | `/resume-from-handoff` |
| Auto-Save für diese Sitzung umschalten | `/handoff-auto on` / `off` / `status` |

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-français"></a>
<details>
<summary><b>🇫🇷 Français</b></summary>

<br>

### Le problème

Quand Claude Code affiche `You've hit your limit · resets ...`, la récupération habituelle — `claude --resume` ou `-c` — recharge **toute la conversation précédente** dans le contexte. Une session de taille moyenne consomme 30,000–200,000 tokens avant que vous n'ayez posé une seule question.

### Ce que fait ce skill

Sauvegarde uniquement le minimum nécessaire pour continuer, structuré dans `.claude/handoff/current.md` (~1–3k tokens) :

- **goal** — ce que vous essayiez d'accomplir
- **done / wip / todo** — terminé / en cours / à faire
- **next_action** — prochaine étape exécutable (`file:line` + commande exacte)
- **touched_files** — fichiers modifiés et la raison
- **decisions** — décisions de conception **et le pourquoi**

Pour reprendre, lancez une **nouvelle session** (PAS `--resume`). Le skill lit uniquement ce fichier et continue.

### Installation

**Plugin (recommandé) — exécuter dans Claude Code :**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. enregistrer le marketplace
/plugin install handoff-revive@handoff-revive-marketplace   # 2. installer le plugin
```

> Si `/plugin isn't available in this environment` apparaît, votre version de Claude Code est trop ancienne. Vérifiez avec `claude --version` et mettez à jour via `brew upgrade claude-code` ou `npm update -g @anthropic-ai/claude-code`.

**Installation manuelle (fonctionne toujours) :**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell
```

### Utilisation

| Action | Tapez dans Claude Code |
|---|---|
| Sauvegarder le handoff | `/handoff` |
| Sauvegarder avec vérification qualité | `/handoff --verify` |
| Reprendre dans une **NOUVELLE session** | `/resume-from-handoff` |
| Basculer l'auto-sauvegarde pour cette session | `/handoff-auto on` / `off` / `status` |

### License

MIT — see [LICENSE](LICENSE).

</details>

---

<a id="-türkçe"></a>
<details>
<summary><b>🇹🇷 Türkçe</b></summary>

<br>

### Sorun

Claude Code `You've hit your limit · resets ...` mesajını gösterdiğinde, olağan kurtarma — `claude --resume` veya `-c` — **tüm önceki konuşmayı** bağlama yeniden yükler. Orta ölçekli bir oturum, tek bir soru sormadan önce 30,000–200,000 token tüketir.

### Bu skill ne yapar

Devam etmek için yalnızca gerekli olan minimumu yapılandırılmış olarak `.claude/handoff/current.md` dosyasına kaydeder (~1–3k token):

- **goal** — neyi başarmaya çalıştığınız
- **done / wip / todo** — tamamlandı / devam ediyor / beklemede
- **next_action** — somut sonraki adım (`file:line` + tam komut)
- **touched_files** — dokunulan dosyalar ve nedeni
- **decisions** — tasarım kararları **ve nedenleri**

Devam etmek için **yeni bir oturum** başlatın (`--resume` KULLANMAYIN). Skill yalnızca bu dosyayı okur ve devam eder.

### Kurulum

**Plugin (önerilen) — Claude Code içinde çalıştırın:**

```sh
/plugin marketplace add sofumel/claude-handoff-revive       # 1. marketplace'i kaydet
/plugin install handoff-revive@handoff-revive-marketplace   # 2. plugin'i yükle
```

> `/plugin isn't available in this environment` görürseniz, Claude Code sürümünüz çok eski. `claude --version` ile kontrol edin ve `brew upgrade claude-code` veya `npm update -g @anthropic-ai/claude-code` ile güncelleyin.

**Manuel kurulum (her zaman çalışır):**

```sh
git clone https://github.com/sofumel/claude-handoff-revive.git
cd claude-handoff-revive
./install.sh /path/to/your-project        # Linux/macOS/WSL/Git-Bash
# .\install.ps1 -Target C:\path\to\proj   # Windows PowerShell
```

### Kullanım

| Eylem | Claude Code'a yazın |
|---|---|
| Handoff kaydet | `/handoff` |
| Kalite kontrolüyle kaydet | `/handoff --verify` |
| **YENİ oturumda** devam et | `/resume-from-handoff` |
| Bu oturum için otomatik kaydı değiştir | `/handoff-auto on` / `off` / `status` |

### License

MIT — see [LICENSE](LICENSE).

</details>


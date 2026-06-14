# handoff-revive（日本語リファレンス）

> **これは人間の読者向けの参照翻訳です。** Claude Code が実際に読み込むのは
> `SKILL.md`（英語・正本）だけです。挙動に関する記述が食い違う場合は常に
> `SKILL.md` が優先されます。翻訳の更新漏れに気づいたら issue / PR を歓迎します。

後で作業を続けるために必要な最小限の状態を保存し、次のセッションを（`--resume` / `-c` ではなく）新規で開始して、小さなファイル1つだけを読み込んで再開します。

## なぜ `claude --resume` を使わないのか

`--resume` と `-c` は、それまでの会話全体をコンテキストに再生します。典型的なセッションで**数万トークン**（長いセッションでは **10万超**）を、何も質問しないうちに消費します。handoff ファイルなら **1,000〜3,000 トークン**です。handoff があるときは常にそちらを優先します。

## 2つのモード

### Mode 1: SAVE（`/handoff-revive:save`）

トリガーは次の場合**のみ**:
- ユーザーがスラッシュコマンド `/handoff-revive:save` を実行した
- UserPromptSubmit hook が auto-save コンテキストを注入した（Mode 1c）

「保存して」「ハンドオフ」「チェックポイント」などの自然言語では**起動しません**。スラッシュコマンドなしでそれらの言葉を見たら、通常のメッセージとして扱い、`/handoff-revive:save` を案内するに留めます。

手順:

1. **言語検出** — `.claude/handoff/lang` があれば読む。なければユーザーの直近メッセージから判定（ひらがな/カタカナ→`ja`、ハングル→`ko`、簡体字マーカー→`zh`、繁体字マーカー→`zh-TW`、ラテン文字はダイアクリティクスと頻出語で `fr`/`de`/`pt`/`es`/`tr`、それ以外→`en`）。判定した言語コードを `.claude/handoff/lang` に書き込む（改行なし）。

2. **引き継いでからスキーマを埋める** — 既存の `.claude/handoff/current.md` があれば先に読み、まだ有効な `goal` / `decisions` / `lessons_learned` を引き継ぐ（古くなったものは捨てる）。長いセッションで効く: 早い段階の保存で書き留めた内容は、その後コンテキストから消えても残る。そのうえで下のテンプレートに従って `.claude/handoff/current.md` に書く。セクションのキーは英語のまま（機械可読）、値はユーザーの言語で。このセッション中に試して捨てたアプローチがあれば `## lessons_learned`（attempted / why_abandoned / learned）に記録。なければセクションごと省略。

   **上書きガード**: 既存の `current.md` の `branch:` メタデータが現在の git ブランチと異なる場合、それは*別の作業*のものである可能性が高い。上書き前にユーザーに確認する（AUTO-SAVE 時は確認せず実行し、通知の中でクロスブランチ上書きに言及する）。

3. **`next_action` は実行可能に。**「認証のリファクタを続ける」ではなく `Edit src/auth/login.ts:42 — bcrypt.compare 呼び出しを timing-safe 版に置換`。正確な file:line と次のコマンド/編集を書く。再開時の「考える時間」をゼロにするのが目的。

4. **`touched_files` は `path -- 理由` 形式。** 区切りは ` -- `（スペース2ハイフンスペース）。`:` は使わない（Windows の絶対パス `C:\...` が壊れるため）。**プロジェクト相対パス + スラッシュ**を優先。トークン節約のため `extract-recent-files` スクリプトの利用を推奨（`git status` ＋ このセッション中のコミット分を決定論的に列挙）。

5. **`finalize-handoff` を実行** — validate + cleanup + メタデータ注入 + 履歴スナップショット + 節約レポートを1コールで行う、トークン消費ゼロのシェルスクリプト。
   - 終了コード 0: 保存完了。stderr の節約見込み行をユーザーへの確認に含める。
   - 終了コード 1: バリデーション失敗。stderr の指摘を直して再実行（**最大2リトライ**。それでも失敗したら残エラーと共にユーザーに報告）。

6. **内容の質チェック（AUTO-SAVE を含むすべての保存）** — goal は文脈ゼロの読者に通じるか、decisions に本当の理由があるか、blockers は回答可能な質問か、wip は途中再開できる精度か、lessons_learned は「本当に失敗した試行」か（選ばなかっただけの選択肢は decisions へ）。弱い欄は書き直して再 finalize。AUTO-SAVE では制限間際なので、1回さっと見直す程度にとどめ、何度も繰り返さない。

7. **ユーザーの言語で確認を返す。** 保存パス、next_action の1行要約、節約見込み、そして「再開は**新規セッション**で `/handoff-revive:resume`（`claude --resume` は使わない）」のリマインド。

### Mode 1b: 内容の質チェック（上記の手順6）

決定論的バリデータは*構造*の問題を無料で捕まえます。手順6の内容チェックは、バリデータにできない*内容品質*の確認を加えるものです。

### Mode 1c: AUTO-SAVE（hook トリガー、ユーザー要求なし）

**UserPromptSubmit hook が `additionalContext` を注入**したときに発火します（usage-monitor が 5 時間使用率のしきい値 90%/95% 超過を検出した後）。

1. **許可を求めない。** auto-save を有効のままにしていること自体が暗黙の同意。
2. **SAVE フロー全体を実行**（Mode 1 の手順1〜6。品質チェックも含むが、制限間際なので1回さっと済ませ、何度も繰り返さない）。
3. **応答の冒頭に短い auto-save 通知**をユーザーの言語で付け、区切り線の後に本来のリクエストを処理する。
4. finalize が2リトライ後も失敗したら、短く警告した上でリクエスト処理を優先する。

### Mode 2: RESUME（新規セッション、制限リセット後）

トリガーは次の場合**のみ**:
- ユーザーが `/handoff-revive:resume` を実行した
- SessionStart hook が `current.md`（`HANDOFF_SURFACE_DAYS` 日以内、デフォルト7）の存在を notify し、その後ユーザーが `/handoff-revive:resume` を実行した（それより古くても resume は使える。自動通知されないだけ）

「続きから」「continue」などの自然言語では起動しません。

手順:

1. `.claude/handoff/current.md` を読む。**過去セッションのトランスクリプトは読まない。**
2. `.claude/handoff/lang` を読み、その言語で応答する。
3. **鮮度チェック**（トークンゼロ）— `check-freshness` スクリプトが handoff の `base_commit` / `branch` を現在の git 状態と照合。出力なし=新鮮。警告（保存後のコミット数 / ブランチ不一致 / 照合不可）が出たら、再開サマリの冒頭で**ユーザーの言語で**伝える。警告は情報提供であり、再開をブロックしない。
4. `touched_files` のファイルは、直近の `next_action` に必要なものだけ読む。
5. goal と `next_action` を1〜2文で復唱し、「進めますか?」と確認してから編集する。
6. 確認後、`next_action` を実行する。

## スキーマ（テンプレート）

`SKILL.md` の Schema (template) セクションを参照（英語が正本）。要点:

- frontmatter: `schema_version: "1.0"` / `saved_at` / `lang` / `session_summary_tokens_estimated`
- 必須セクション: `goal` `done` `wip` `todo` `next_action` `touched_files` `decisions`
- 任意セクション: `blockers` `lessons_learned`（空なら省略。cleanup が自動で削除）
- `author` / `author_email` / `branch` / `base_commit` / `created_at` は **finalize-handoff が自動注入**するので自分で書かない（`HANDOFF_HIDE_EMAIL=1` で email 省略）
- **テンプレート（任意）**: `--template=vacation-handover` で長期離脱向け変種に切替（`templates/vacation-handover.md` 参照。`## handover_notes` が必須になる）
- **未作成ファイルの参照**（TDD・計画中の作業）: touched_files では `- path -- planned: 理由`、next_action では行頭に `# planned:` を付けるとバリデータの実在チェックを意図的にバイパスできる

## してはいけないこと

- 再開時に過去セッションのトランスクリプトを読まない。handoff ファイルが唯一の情報源。
- hook から黙って save を自動起動しない（ユーザーが知らないままトークンを消費する）。hook は*促す*だけ。
- 会話全体を handoff に書かない。スキーマの欄だけ。
- `current.md` が存在するのに `--resume` / `-c` を使わない。先にユーザーに警告する。
- セクションキーを翻訳しない。キーは英語、値はユーザーの言語。

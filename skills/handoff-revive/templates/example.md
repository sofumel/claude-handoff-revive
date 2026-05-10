---
saved_at: 2026-04-30T22:15:00+09:00
lang: ja
session_summary_tokens_estimated: 47000
---

## goal
ユーザー認証に timing-safe な比較を導入し、bcrypt 直接比較によるタイミング攻撃を塞ぐ

## done
- src/auth/login.ts の現状調査完了 (bcrypt.compare 使用箇所を 3 箇所特定)
- crypto.timingSafeEqual を使うヘルパー src/auth/safe-compare.ts を新規作成
- 単体テスト tests/auth/safe-compare.test.ts を追加・パス確認

## wip
- login.ts の bcrypt.compare 呼び出しを safe-compare に置換中 (1/3 完了)

## todo
- login.ts の残り 2 箇所を置換
- password-reset.ts の同様の置換
- 統合テスト (tests/integration/auth.test.ts) の実行
- CHANGELOG.md に security fix を追記

## blockers
- なし

## next_action
Edit src/auth/login.ts:42 — `bcrypt.compare(password, user.hash)` を `await safeCompare(password, user.hash)` に置換。インポートも追加: `import { safeCompare } from './safe-compare'` を line 8 に。

## touched_files
- src/auth/login.ts -- 置換対象（残り 2 箇所: line 42, 78）
- src/auth/safe-compare.ts -- 新規作成済み・確定
- src/auth/password-reset.ts -- 同パターンで置換要 (line 31)
- tests/auth/safe-compare.test.ts -- 完成済み・パス
- CHANGELOG.md -- security セクションへの追記が必要

## decisions
- bcrypt 自体は維持し比較関数だけ差し替える: WHY — bcrypt のハッシュ強度は問題なく、変更の影響範囲を比較ロジックだけに限定するため
- safeCompare は async に: WHY — 将来 KMS 経由の比較に切り替える余地を残すため、最初から非同期 API に統一

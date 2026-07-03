---
name: codex-review
description: >
  codex-cli を使ったコードレビューおよびプラン/設計レビューのワークフロー。
  レビュー結果に基づいてコードやプランを修正し、必要に応じてユーザーに確認を求める。
  修正後のフォローアップレビューではcodexセッションを引き継いで継続できる。
  トリガー: (1) ユーザーが「codexでレビュー」「codex review」「codexにレビューさせて」
  と言ったとき、(2) コード変更やプランの外部レビューが求められたとき、
  (3) 「レビュー」と言われてcodex-cliの利用を示唆されたとき。
  codex-cli（`codex`コマンド）がインストール済みで、同一リポジトリにアクセスできる前提。
---

# Codex Review

codex-cli を外部レビュアーとして活用し、レビュー結果に基づいて修正を行うワークフロー。

## 前提条件

- `codex` コマンドがインストール済み
- codex の設定（`~/.codex/config.toml`）でモデル等が設定済み
- codex が同一リポジトリを参照できる状態

## ワークフロー

### Phase 1: レビュー対象の特定

ユーザーの要求から以下を判定:

| 要求 | レビューモード | codex コマンド |
|------|---------------|---------------|
| コード変更のレビュー（未コミット） | code-uncommitted | `codex review --uncommitted` |
| ブランチ差分のレビュー | code-base | `codex review --base <branch>` |
| 特定コミットのレビュー | code-commit | `codex review --commit <SHA>` |
| プラン/設計のレビュー | plan | `codex exec -s read-only` |
| カスタムレビュー | custom | `codex exec -s read-only` |
| 修正後の再レビュー | resume | `codex exec resume <SESSION_ID>` |

### Phase 2: レビューの実行

ヘルパースクリプト `scripts/codex_review.sh` を使用:

```bash
# コードレビュー（未コミット変更）
bash scripts/codex_review.sh code-uncommitted "追加のレビュー指示"

# ブランチ比較レビュー
bash scripts/codex_review.sh code-base staging "追加の指示"

# 特定コミットのレビュー
bash scripts/codex_review.sh code-commit abc1234 "追加の指示"

# プランレビュー（ファイル指定）
bash scripts/codex_review.sh plan /path/to/plan.md "追加の指示"

# セッション継続でのフォローアップレビュー
bash scripts/codex_review.sh resume <SESSION_ID> "修正した箇所を確認してください"
```

レビュープロンプトのテンプレートは [references/review-prompts.md](references/review-prompts.md) を参照。

**重要**: codex review コマンドはタイムアウトに10分を設定すること（`timeout: 600000`）。

### Phase 3: レビュー結果の解析と分類

codex の出力を以下の3カテゴリに分類:

1. **自動修正可能（AUTO-FIX）**: 明確なバグ修正、タイポ、フォーマット修正など
   - Claude が即座に修正を実行
   - 修正内容をユーザーに報告

2. **ユーザー確認必要（NEEDS-CONFIRM）**: 設計判断、トレードオフ、仕様確認が必要な指摘
   - 指摘内容をユーザーに提示
   - 選択肢がある場合は AskUserQuestion で確認
   - ユーザーの判断を待って修正

3. **情報提供（INFO）**: 改善提案、スタイル提案など対応任意の指摘
   - ユーザーに報告するが、即時の対応は不要

### Phase 4: 修正の実行

分類に基づいて修正を実行:

```
AUTO-FIX の指摘 → Edit ツールで即時修正 → 修正内容を報告
NEEDS-CONFIRM の指摘 → ユーザーに確認 → 承認後に修正
INFO の指摘 → まとめて報告のみ
```

修正時の注意:
- 1つずつ指摘に対応し、修正の影響範囲を最小限に保つ
- 修正前に対象ファイルを Read で確認する
- CRITICAL な指摘を最優先で処理する

### Phase 5: フォローアップレビュー（セッション継続）

修正完了後、codex のセッションを引き継いで再レビューを実行:

1. Phase 2 で取得した `SESSION_ID` を保持
2. `codex exec resume <SESSION_ID>` で前回のコンテキストを引き継ぐ
3. 修正内容を確認させるプロンプトを渡す

```bash
bash scripts/codex_review.sh resume <SESSION_ID> \
  "前回の指摘に対して以下の修正を行いました。修正が適切か確認してください:
  1. <修正内容1>
  2. <修正内容2>
  新たな問題がないかも確認してください。"
```

**セッションIDの管理**:
- レビュー実行時に出力末尾の `SESSION_ID:` 行からIDを取得
- 同一レビューサイクル内はこのIDを保持し続ける
- セッションファイルは `/tmp/codex-review/session_*.txt` にも保存される

### Phase 6: 完了報告

全ての指摘への対応が完了したら、ユーザーに最終報告:

```
## Codex Review 完了サマリー

### 対応済み
- [CRITICAL] xxx → 修正済み
- [WARNING] yyy → 修正済み

### ユーザー確認済み
- [WARNING] zzz → ユーザー判断により対応なし

### 情報提供
- [INFO] aaa → 将来の改善候補として記録

### セッション情報
- Session ID: <SESSION_ID>（再レビューに使用可能）
```

## codex コマンドの直接実行

スクリプトを使わずに直接 codex を呼ぶ場合のリファレンス:

```bash
# 基本的なコードレビュー
codex review --uncommitted "レビュー指示"
codex review --base main
codex review --commit <SHA>

# exec モード（read-only sandbox）
codex exec -s read-only -o /tmp/review_output.md "プロンプト"

# セッション再開（非インタラクティブ）
codex exec resume <SESSION_ID> -o /tmp/review_output.md "フォローアッププロンプト"

# JSONL出力で構造化データを取得
codex exec -s read-only --json "プロンプト"
```

## エラーハンドリング

- codex コマンドがタイムアウトした場合: timeout を延長して再実行
- セッションIDが見つからない場合: 新規セッションで再レビュー
- codex の出力が空または不明確な場合: プロンプトを具体化して再実行

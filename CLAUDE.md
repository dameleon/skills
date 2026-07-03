# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このリポジトリの位置づけ

Agent Skills（[agentskills.io](https://agentskills.io/specification) のオープン仕様に準拠したスキル）を作成・管理するためのリポジトリ。

## このリポジトリでの作業

`main` への直接コミット・push を許容する。専用 worktree を切らず `main` で作業してよい（グローバル既定の worktree 隔離を、このリポジトリに限り上書き）。push ガード（`~/.claude/hooks/guard-push.sh`）の allow list には登録済み。

## スキルの構造（agentskills.io 仕様）

新しいスキルを追加・編集するときは、以下を必ず守る。これはこのリポジトリの規約であり、`/init` 実行時点で外部仕様を写したものなので、迷ったら [仕様ページ](https://agentskills.io/specification) を正とする。

1 スキル = `SKILL.md` を含む 1 ディレクトリ。任意で `scripts/`（実行コード）、`references/`（オンデマンドで読む詳細ドキュメント）、`assets/`（テンプレート・データ）を置く。

`SKILL.md` は YAML frontmatter + Markdown 本文。frontmatter の制約は厳密で、ここを外すとバリデーションに落ちる。

- `name`（必須）: 1〜64 文字。小文字英数字（`a-z` `0-9`）とハイフンのみ。先頭・末尾にハイフン不可、連続ハイフン（`--`）不可。**親ディレクトリ名と完全一致させる**。
- `description`（必須）: 1〜1024 文字。「何をするスキルか」と「いつ使うか」の両方を書き、エージェントが該当タスクを見分けられるキーワードを含める。`Helps with X.` のような曖昧な一行にしない。
- `license` / `compatibility`（1〜500 文字、環境要件がある場合のみ）/ `metadata`（文字列 key-value）/ `allowed-tools`（空白区切り、実験的）は任意。

本文フォーマットに制約はないが、progressive disclosure を前提に設計する。`name`+`description` は起動時に全スキル分ロードされ、本文はスキル起動時に丸ごとロードされる。よって **`SKILL.md` は 500 行未満**に抑え、詳細は `references/` の個別ファイルへ逃がして必要時だけ読ませる。ファイル参照はスキルルートからの相対パスで、ネストは 1 階層まで。

## バリデーション

frontmatter と命名規約は、`agentskills/agentskills` の `skills-ref` で検証できる（このリポジトリには未同梱の外部ツール）。

```bash
skills-ref validate ./<skill-dir>
```

## レイアウトと配布（未確定・参照モデル）

このリポジトリはまだカテゴリ分けも配布マニフェストも持たない。方式を決める際の参照モデルは以下。**現時点でこれらのコマンドやマニフェストは存在しないので、`apm.yml` 等が実際にコミットされるまで「使える」前提で書かない**。

- ドメイン別カテゴリディレクトリで整理し、per-skill README を `SKILL.md` から自動生成する運用: [mizchi/skills](https://github.com/mizchi/skills)（`apm.yml` + waxa CLI を併用）。
- 配布・再現を担うマニフェスト方式: [microsoft/apm](https://github.com/microsoft/apm)（Agent Package Manager）。`apm.yml` で依存を宣言し `apm install` で再現、`apm.lock.yaml` でピン留め、`apm compile -t <agent>` で各エージェント向けに出力。

配布ツール（APM など）を導入する場合は、対応するマニフェストを追加した時点で、この節を「実際に使えるコマンド」に書き換える。

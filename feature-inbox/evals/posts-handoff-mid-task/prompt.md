---
tags: [feature-inbox]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

今日の作業はここまでにする。状況をまとめると:

- PR #45（feat/notification-settings）で設定画面の UI と保存 API を実装して、いまレビュー待ち。
- セッション冒頭で私から「通知チャネルは v1 ではメールのみ。Slack は認証基盤の OAuth 対応待ちなので v2」と伝えた。これは inbox の Q-1 の答えになるはず。
- レビュー指摘で「既読フラグを通知単位にするかスレッド単位にするか」が出た。現行 UI はスレッド単位、API は通知単位で返している。UX 方針なので私が決めないといけない。
- 作業中に `NotificationList#index`（app/controllers/notification_list.rb:34）が送信者ごとに user を引いていて N+1 になっているのを見つけたが、今回の変更とは無関係なので直していない。
- ステージングは `MAIL_DRIVER=log` のままなので、本番相当のメール確認をするときは smtp に切り替える必要がある。
- 頻度の選択肢は「即時 / 毎日 / 毎週」の 3 つで実装した。これは私が指示したわけではなく、既存の digest ジョブが日次・週次しか持たないという理由でエージェント側で決めたものなので、後で覆せるように記録しておいて。

ここまでの報告・未決・引継ぎを inbox に入れておいて。

（環境メモ: このプロジェクトでは GitHub CLI として `./bin/gh` を使う。作業前に `export PATH="$PWD/bin:$PATH"` を実行すること。リポジトリは acme/notify として扱う。）

---
tags: [feature-inbox]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

通知設定画面の inbox、コメントが溜まって何が決まって何が残ってるのか分からなくなってきた。inbox をまとめて、最新状況と未決リストを整理して。

（環境メモ: このプロジェクトでは GitHub CLI として `./bin/gh` を使う。作業前に `export PATH="$PWD/bin:$PATH"` を実行すること。リポジトリは acme/notify として扱う。）

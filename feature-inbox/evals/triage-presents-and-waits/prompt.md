---
tags: [feature-inbox]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

通知設定画面の inbox に残ってる未決、そろそろ片付けたい。判断材料を出して。

（環境メモ: このプロジェクトでは GitHub CLI として `./bin/gh` を使う。作業前に `export PATH="$PWD/bin:$PATH"` を実行すること。リポジトリは acme/notify として扱う。）

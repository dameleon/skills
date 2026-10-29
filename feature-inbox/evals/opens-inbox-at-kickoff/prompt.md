---
tags: [feature-inbox]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

通知設定画面の feature にこれから着手する。ユーザーが通知のチャネル（メール / Slack）と頻度を自分で設定できる画面と、その保存 API。epic は #5 で、設計はこれから相談するけど、未決や引継ぎを溜める場所が先に欲しいので /feature-inbox open 通知設定画面 で inbox を作っておいて。

（環境メモ: このプロジェクトでは GitHub CLI として `./bin/gh` を使う。作業前に `export PATH="$PWD/bin:$PATH"` を実行すること。リポジトリは acme/notify として扱う。）

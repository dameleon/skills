---
name: herdr
description: >-
  Use when running inside Herdr v2 (herdr-core; `$HC_TERMINAL_ID` is set) and the task touches
  other terminals, agents, machines, or the Herdr window: delegating work to another agent in a
  new terminal, sending to / reading / waiting on other panes, checking what other agents are
  doing (`hc ls`), running slow commands without blocking yourself, running commands or editing
  files on a remote machine, or creating / arranging spaces, tabs, and splits in the window.
  Triggers: "hc", "herdr", "別ペインの agent", "他のターミナル", "子 agent を立てて", "並列で agent を走らせて",
  "redmagic で実行", "タブを開いて", "スペースを作って". This skill only points to the live manuals
  printed by `hc --skill` and `herdr-app --skill`, so it stays current as Herdr updates.
---

# herdr — Herdr v2 (hc / herdr-app) の入口

Herdr v2 のマニュアルは CLI 自身が出力する。
この skill は中身を写さず、最新のマニュアルを読ませる入口だけを担う。

## 手順

1. `echo "$HC_TERMINAL_ID"` で自分のアドレス（例: `t5`）を確認する。
   空なら Herdr v2 の中ではないので、この skill は使わずに通常どおり作業する。
2. 用途に応じてマニュアルを読み、その指示に従う。
   - ターミナルと agent の操作（起動、送信、読み取り、待機、リモート実行、ファイル操作）: `hc --skill`
   - ユーザーに見えるウィンドウの操作（space、tab、split、フォーカス、mod）: `herdr-app --skill`
   両方が必要なら両方読む。
   同じセッションで一度読んだら、読み直さなくてよい。

## 使わないもの

`herdr` コマンドは v1（旧ターミナルマルチプレクサ）で、使っていない。
`herdr --help` が案内する `herdr --skill` や `herdr api` / `herdr agent` などは実行しない。
v2 の操作は `hc` と `herdr-app` だけで行う。

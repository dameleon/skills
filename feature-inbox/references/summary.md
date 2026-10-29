# feature-inbox: summary

Rebuild the summary region from everything posted so far. Read this before running
`summary`.

## 1. Fetch everything

```bash
gh issue view <N> --json number,title,url,body,comments
```

`comments` here is capped at 100. If the result has 100 comments, or the meta block's
`summarized-through:` is older than what you see, fetch the full set instead:

```bash
gh api --paginate repos/{owner}/{repo}/issues/<N>/comments \
  --jq '.[] | {id, created_at, user: .user.login, html_url, body}'
```

Read the comments in chronological order. Humans will not always use the headers — a
reply like "B でいきましょう" under a 未決 is a 決定 in substance.

## 2. Build the item ledger

From the body's current lists and the comments, produce one row per ID:

| ID | type | one-liner | 判断者 | state | source comment | closing comment |
|---|---|---|---|---|---|---|

Rules:

- A `Q-n` is **decided** when a `### [決定] → Q-n` entry exists, *or* a later human
  comment answers it unambiguously. Mark inferred matches with `（推定）` in the output so
  the human can veto. A `### [決定] Q-n` with no prior 未決 is an agent's own choice: it
  goes straight to 決定済み with `決定者: エージェント` and stays flagged that way until a
  human comment confirms or overturns it.
- An inbox comment whose first line links a task-issue comment is a pointer: follow the
  link only when an ID in the inbox lacks detail; the inbox entries themselves are the
  ledger rows.
- An `I-n` is **resolved** when a 報告 or a PR link says so. Otherwise it stays open even
  if it is old.
- An `H-n` is **retired** when a later 報告 / 決定 makes it moot (the dummy SMTP was
  replaced, the workaround was removed).
- Nothing is dropped from the ledger; resolved items just move sections.

Do not renumber. An ID appearing in the comments but not in the counters means a human
posted with a hand-written ID — honour it and bump `last-ids:` past it.

## 3. Rewrite the region

Fetch the body **again** immediately before the edit, then replace only what lies between
`<!-- feature-inbox:summary:start -->` and `<!-- feature-inbox:summary:end -->`, plus the
`summarized-through:` and `last-ids:` lines of the meta block:

```markdown
## 最新状況
- 完了: <what shipped, with PR links — the latest 報告 entries folded together>
- 進行中: <what is in flight and who / which PR has it>
- 次: <the next concrete step, and which Q-n blocks it, if any>
- 直近の方向転換: <決定 entries that changed the plan, if any>

## 未決リスト
- Q-3: 既読フラグの単位 — 判断者: 人間 ([#issuecomment-…](url))
- Q-4: リトライ回数 — 判断者: エージェント可 ([comment](url))

## 課題
- I-2: 通知一覧の N+1 ([comment](url))
- ~~I-1: 保存時の 500~~ 対応済み PR #47

## 決定済み
- Q-1: 通知チャネルは v1 メールのみ — 決定者: `@kei` ([comment](url))
- Q-2: 既読は手動のみ（推定: `@kei` のコメント "手動でいい" より）([comment](url))
- Q-4: 頻度の選択肢は 3 つ — 決定者: エージェント（要確認） ([comment](url))

## 引継ぎ・注意
- H-1: ステージング SMTP はダミー ([comment](url))
```

Keep 最新状況 to what a returning human can act on — a few lines, not a changelog; the
comments already are the changelog. Lists carry one line per item with the comment link,
so the detail is one click away rather than duplicated.

```bash
gh issue edit <N> --body-file <tmp>
```

No comment announcing the summary. The body is the summary; a "まとめました" comment is
noise the next summary has to read past.

## 4. Report

```markdown
## feature-inbox — summary of #<N>
- 畳み込んだコメント: <n> 件（<first date> 〜 <last date>）
- 未決: <n> 件（人間 <m> / エージェント可 <k>） / 課題: <n> / 引継ぎ: <n>
- 推定で決定扱いにしたもの: Q-2（要確認）
- 最新状況: <the three lines>
```

List the open decisions in the chat as well, so the user can go straight to `triage`.

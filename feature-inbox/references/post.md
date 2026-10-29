# feature-inbox: post

File this session's entries into the inbox: one comment, then the body lists. Read this
before running `post`.

## 1. Collect entries

Sources, most reliable first — the same ones `closing` uses, because the two skills are
looking for the same leftovers:

1. What the user dictated in this turn ("これを inbox に").
2. This session's own record: questions you asked and did not get answered, steps dropped
   with "後で" / "別PRで" / "要確認", and choices *you* made where a real alternative
   existed (a data shape, a default, a scope cut) — those become 決定 entries with
   `決定者: エージェント`, so a human can see and overturn them.
3. Review outcomes left unimplemented; findings triaged as 見送り.
4. Bugs and gaps noticed while working that the change did not touch.
5. Temporary workarounds, env-specific hacks, pinned versions, skipped tests.
6. What shipped — PR / commit links, and the next concrete step.

Then ask the one filter question: *would the next person, with only the repo, the PRs and
this inbox, be missing this?* If not, it is not an entry. An empty `post` is a valid
result; say "inbox に追加するものなし" rather than filing filler.

## 1b. Decide where each entry goes

Find the task issue (SKILL.md Step 0: `Closes #N` in the PR body, the branch name, an
`.agent-flow/issue` pointer, or the user naming it). Then route by scope — the inbox is
the feature's memory, the task issue is the task's:

| Entry | Task issue exists | No task issue |
|---|---|---|
| 報告 (full) | task issue comment; the inbox gets one line + a link to that comment | inbox comment |
| 未決 / 決定 that only matter inside the task | task issue comment | inbox comment |
| 未決 / 決定 that affect other tasks, product behaviour, or the plan | inbox comment (link the task issue as 発生元) | inbox comment |
| 課題 | inbox comment | inbox comment |
| 引継ぎ | inbox comment | inbox comment |

The reason for the split: a task issue closes with its PR and nobody re-reads it, so a
decision that shapes the next task would be lost there — but a task's blow-by-blow
report in the inbox is noise the summary has to read past every time. When in doubt
about scope, put it in the inbox; the summary can retire it.

Entries that go to the task issue keep the same headers and get IDs from the same
counters, so a later summary can still match them by ID through the link.

## 2. Type, classify, and assign IDs

Fetch the body first (`gh issue view <N> --json body --jq .body`) and read `last-ids:`
from the meta block. IDs are assigned in order of appearance in your comment, continuing
from those counters, and never reused.

For every 未決, set **判断者**:

- `人間` — scope, priority, product behaviour, money, external commitments, anything
  irreversible, anything the user said they wanted to see first.
- `エージェント可` — implementation choices with a clear technical criterion, where the
  agent could decide given one more fact or a bit of investigation. Say which.

The split is what makes `triage` useful: the human reads the `人間` items and delegates
the rest with one word.

## 3. Comment format

One comment per destination, entries in this order: 決定 → 未決 → 課題 → 引継ぎ → 報告.
A short first line names the source (`PR #45 / 2026-10-28 セッション`); when the task
issue took the report, that first line is the link to the task-issue comment. Headers are
exact — the summary subcommand parses them.

```markdown
PR #45 (feat/notification-settings) の作業より — 詳細報告: #44 のコメント <url>

### [決定] → Q-1: 通知チャネルは v1 ではメールのみ
- 理由: Slack 連携は認証基盤待ち。ユーザー判断（本セッション）
- 決定者: `@kei`

### [決定] Q-4: 頻度の選択肢は 即時 / 毎日 / 毎週 の 3 つ
- 理由: 既存の digest ジョブが日次・週次しか持たず、それ以外は新規実装になるため
- 決定者: エージェント（本セッション。変える場合は言ってください）

### [未決] Q-3: 既読フラグを通知単位にするかスレッド単位にするか
- 背景: 現行 UI はスレッド単位。API は通知単位で返している
- 選択肢: A. 通知単位（API に合わせる・UI 改修要） / B. スレッド単位（集約ロジック追加）
- 推奨: B — UI 変更を避けられ、集約は 1 関数で済む
- 判断者: 人間（UX 方針）
- 発生元: PR #45 のレビュー指摘

### [課題] I-2: 通知一覧の N+1 クエリ
- 内容: `NotificationList#index` が送信者ごとに user を引いている
- 該当箇所: app/controllers/notification_list.rb:34
- 今回の変更との関係: 無関係・既存。修正は含めていない

### [引継ぎ] H-1: ステージングの SMTP はダミー
- `MAIL_DRIVER=log` のまま。本番相当の確認は `MAIL_DRIVER=smtp` に切り替えてから

### [報告] 2026-10-28
- 設定画面の UI と保存 API（PR #45、レビュー中）。詳細は #44 のコメント参照
```

Post the task-issue comment first so its URL can go into the inbox comment's first line.
When there is no task issue, the 報告 block carries the full 完了 / 進行中 / 次 lines
instead of the one-liner.

Backtick every `@handle`. Keep each entry to what a reader with no session context needs;
the comment is the record, the chat is not.

```bash
gh issue comment <task-issue> --body-file <tmp-task>   # when a task issue exists; capture the URL
gh issue comment <N> --body-file <tmp>                 # the inbox comment; capture the URL
```

## 4. Update the body lists (read-modify-write)

Fetch the body **again** now — a human may have edited it while you wrote the comment.
Then, inside the owned regions only:

- meta `last-ids:` → the new counters.
- `## 未決リスト` → append `- Q-n: <one line> — 判断者: 人間 ([comment](url))` for each
  new 未決; remove the placeholder line when the list stops being empty.
- `## 課題` → append `- I-n: <one line> ([comment](url))`.
- `## 引継ぎ・注意` → append `- H-n: <one line> ([comment](url))`.
- `## 決定済み` → for each 決定, move the `Q-n` line here as
  `- Q-n: <answer> — 決定者: <who> ([comment](url))` and delete it from 未決リスト. A minted
  `Q-n` (agent decision with no prior 未決) is simply added here with `決定者: エージェント`.
- `## 最新状況` is not touched by `post` — that is `summary`'s job — unless it still reads
  `_（未集約）_`, in which case put the 報告's three lines there so the top is never empty.

Write back with `gh issue edit <N> --body-file <tmp>`. Everything outside the meta block
and the summary region goes back byte-for-byte.

## 5. Report

```markdown
## feature-inbox — posted to #<N>
- Inbox comment: <url> / タスク issue #<task> への報告: <url> | なし
- 追加: Q-3 (人間), I-2, H-1 / 決定: Q-1 (`@kei`), Q-4 (エージェント判断・要確認)
- 未決リスト: 現在 <n> 件（うち 人間 <m> 件） → `/feature-inbox triage` で判断材料を出せます
```

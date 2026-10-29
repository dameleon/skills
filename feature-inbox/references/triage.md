# feature-inbox: triage

Give the human what they need to settle the open decisions, then record what they
decide. Read this before running `triage`.

## 1. Load the open items

Run the summary's ledger step (summary.md §1–2) without writing anything, or, when the
meta block's `summarized-through:` matches the latest comment, read the 未決リスト
straight from the body. Open `Q-n` only; 課題 and 引継ぎ are shown as context, not triaged.

If the list is empty, say so, show 最新状況, and stop. Inventing questions to look useful
is the failure mode here.

## 2. Prepare each item

Order: `判断者: 人間` first, oldest first within that; then `エージェント可`. For each,
re-read its source comment and anything that references the ID, then write:

```markdown
### Q-3: 既読フラグを通知単位にするかスレッド単位にするか      判断者: 人間
**要点**: 現行 UI はスレッド単位、API は通知単位。どちらに寄せるかで一覧の集約実装と
UX が変わる。PR #45 のレビューで指摘。次の実装（一覧の集約）がこれに依存している。
**選択肢**
- A. 通知単位 — API そのまま。UI 改修（一覧の行の粒度変更）が必要。既存ユーザーの見え方が変わる
- B. スレッド単位 — UI 据え置き。API 応答を集約する関数を 1 つ追加。通知数の正確さは落ちる
**推奨**: B — UI 変更の影響範囲が読めない一方、集約は局所的で戻しやすい
**必要なもの**: A / B の選択。B の場合、未読数をスレッド数で出してよいかも一言
```

Costs are the real ones: time, reversibility, who else is affected. A recommendation is
mandatory — presenting options without one pushes the work back to the human, and the
agent usually has the better view of the code. Mark anything the recommendation depends
on that you could not verify.

For `エージェント可` items, add one line: `エージェントで決められます（<what would
settle it>）— 任せる場合はそう言ってください`.

## 3. Present and stop

Show the blocks, then two short context lists: 決定済み entries with `決定者: エージェント`
that no human has confirmed (one line each — "覆すならここ"), and the open 課題 / 引継ぎ.
Then end the turn. The human's answer is the input for step 4; do not pre-empt it.

Accepted forms of an answer: a choice ("Q-3 は B"), a constraint that settles it ("既存
ユーザーの見え方は変えない" → B), a delegation ("Q-4 は任せる"), or a deferral ("Q-3 は来
週"). Anything else — ask one clarifying question for that item only.

## 4. Record

Via `post`'s rules (post.md §3–4), one comment:

- Each answered item → `### [決定] → Q-n: <answer>` with 理由 (the human's words, or the
  recommendation they accepted) and 決定者 (backticked handle, or `人間（セッション内）`).
- Each delegated `エージェント可` item → decide it now, and record it as a 決定 whose 理由
  states it was delegated and on what basis.
- Each deferred item stays in 未決リスト; append `（<date> 保留）` to its line.
- An agent decision the human confirms keeps its line with `決定者: エージェント（確認済み）`;
  one they overturn gets a new `### [決定] → Q-n` with the human's answer, and the line
  is replaced.

Then update the body lists: decided `Q-n` lines move to 決定済み. If the decision changes
最新状況's 次 line, update that line too.

## 5. Report

```markdown
## feature-inbox — triage of #<N>
- 決定: Q-3 → B, Q-4 → （委任）3 回 ([comment](url))
- 保留: Q-5（来週）
- 残り未決: <n> 件
- 次の作業: <what the decisions unblock>
```

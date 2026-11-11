---
name: feature-inbox
description: >-
  Use for the per-feature / per-epic **inbox issue** — one shared GitHub issue (or the
  project's tracker) where humans and agents keep what a feature accumulates across many tasks
  and sessions: open decisions (未決 Q-n), problems found (課題 I-n), handoffs (引継ぎ H-n), progress
  reports, and recorded decisions (決定). Invoke when the user answers, defers, or delegates a
  tracked item by its ID and wants it recorded ("Q-3 は B で", "Q-4 は任せる、記録して"), wants decision
  material for open items (context, options, costs, recommendation), asks to create the issue
  when a feature's design / planning starts, wants this session's open questions, findings,
  report, or handoff filed for the next person, or wants scattered comments folded into
  current status and an open-decision list. Offer it once when feature-level design begins and
  no inbox exists. Not agent-flow's per-PR tracking issue, not closing's session wrap-up (its
  handoff posts here), not email inboxes.
argument-hint: "[open|post|summary|triage] [feature title | #issue | issue URL]"
---

# Feature Inbox — epic / feature 単位の未決・課題・引継ぎの置き場

A feature spans many sessions, several branches, and both humans and agents. What falls
between those cracks is never the code — it is the *decision somebody still has to make*,
the *bug somebody noticed and did not fix*, and the *context the next person will need*.
This skill gives each feature one place for those, and keeps the top of that place current
so a human can read it in a minute:

```
open    → one issue per feature; title "inbox: <feature>", label feature-inbox,
           body = skill-owned summary region + human free-text area
post    → entries from this session, typed and ID'd, as ONE comment; lists in the
           body updated so the top stays current
summary → fold all comments into 最新状況 / 未決リスト / 課題 / 決定済み / 引継ぎ
triage  → per open decision: context, options with costs, recommendation, what is
           needed from the human; on an answer, record a 決定
```

Three constraints run through every subcommand.

**本文は人間と共有している。** Unlike a bot-only tracking issue, people type into this body.
The skill therefore owns exactly two regions — the leading `<!-- feature-inbox:meta -->`
block and the span between `<!-- feature-inbox:summary:start -->` and
`<!-- feature-inbox:summary:end -->` — and never rewrites anything outside them. Every
body write is read-modify-write with a fetch immediately before the edit (issue bodies
have no compare-and-swap; a human editing the free-text area at the same time would
otherwise be clobbered).

**項目には ID がある。** A question raised in comment 7 and answered in comment 23 must be
matchable by something other than prose. Every open decision, problem, and handoff gets
an ID (`Q-n` / `I-n` / `H-n`) at post time; a 決定 references the `Q-n` it closes. The
summary and triage subcommands work from those IDs, not from guessing.

**人間でしか判断できないことは人間が決める。** The skill classifies each open decision as
`判断者: 人間` or `判断者: エージェント可`, prepares the material for the human ones, and
never posts a 決定 for a human-only item without the human's actual answer. It also never
closes the inbox issue — the feature's end is the human's call.

## Step 0: Resolve the subcommand and the inbox

From `$ARGUMENTS`: the first token is the subcommand (`open` / `post` / `summary` /
`triage`). No subcommand means: if no inbox can be found, `open`; otherwise `post` when the
session holds something to file, else `triage`. The remainder is the feature title (for
`open`) or an inbox locator (`#N`, a number, or an issue URL).

### Repository

The inbox lives in the repository the feature belongs to, which means the cwd must be
inside one (`git rev-parse --show-toplevel`). Outside a repository, or when the user has
not named one, stop and ask which repo — do not go looking through every checkout on the
machine, and never run tracker searches against repositories the user did not point at.

### Tracker

GitHub issues via `gh` is the default. A project may name another tracker in its own
context (`CLAUDE.local.md`, `.claude/rules/*.md`, `CLAUDE.md`, in that order); when it
does, read `references/trackers.md` for that tracker's equivalents of body / comment /
search. An unauthenticated or missing CLI is a stop-and-report, never a silent switch of
tracker.

### Finding the inbox (first match wins)

1. An explicit `#N` / number / URL in the arguments.
2. Project context naming the inbox for this feature — a line like
   `feature-inbox: <feature> → #N` in `CLAUDE.local.md`, `.claude/rules/*.md`, or `CLAUDE.md`.
3. An `inbox: #N` / `inbox: <url>` reference in the current branch's PR body or in the
   issue that seeded this work.
4. Search **this repository only**: `gh issue list --label feature-inbox --state open
   --search "<feature words>"`, then match on the `inbox: ` title prefix. Several hits, or
   none when the user expects one, means ask — do not pick the newest.

Record what resolved the inbox; `post` and `summary` report it so a wrong match is visible
before anything is written.

### Finding the task issue (for `post`)

Most sessions work on one task inside the feature, and that task often has its own
issue: the one the PR says it closes (`Closes #N` in `gh pr view --json body`), the number
in the branch name (`feat/44-…`, `issue-44`), an agent-flow tracking issue
(`.agent-flow/issue`), or one the user names. When such an issue exists, the task's own
report belongs there and the inbox only links to it — see `post`. When none exists, the
inbox comment carries the report itself.

## open — create the inbox at the start of a feature

Read `references/open.md` before running it. In short:

1. Preflight: `gh auth status`; `gh repo view --json nameWithOwner,hasIssuesEnabled`.
2. Search for an existing inbox for this feature (Step 0, item 4) — a second inbox for the
   same feature splits the record, which is worse than none.
3. Create from `templates/INBOX.md`: title `inbox: <feature title>` (a human phrase, not a
   slug), label `feature-inbox` (create-if-missing), body with the meta block, 概要 filled
   from the conversation so far (design links, related issues, scope in a few lines), and
   an empty summary region. Link the epic from 概要; nest the inbox under it with
   `--parent` only when the user asks — it restructures someone else's issue.
4. Make the inbox findable next session: propose the one-line pointer for project context
   and write it to `CLAUDE.local.md` when that file is gitignored (local, reversible);
   otherwise show the line and let the user place it.
5. Report the URL and the pointer.

**When triggered proactively** (a feature-level design conversation starts and Step 0 finds
no inbox): creating an issue is an external, team-visible write, so *offer* it once in a
sentence and continue the conversation. Create directly only when the user invoked `open`
or said yes.

## post — file what this session produced

Read `references/post.md` before running it. The point of `post` is that nothing the
session learned dies with the session, and that the human reading the inbox top sees it
without scrolling. So:

1. Collect entries from the session: decisions deferred to someone else, questions the
   agent could not settle, choices the agent made on its own that a human should be able
   to overturn, bugs or gaps noticed but not fixed, what shipped (with PR / commit links),
   and what the next person needs to know. Entries the user dictated come first; add the
   ones the session record supports.
2. Type each entry and assign IDs from the meta block's counters:

   | Type | Header | ID | Needs |
   |---|---|---|---|
   | 未決 (open decision) | `### [未決] Q-n: <one line>` | yes | 背景 / 選択肢とその代償 / 推奨 / **判断者: 人間 or エージェント可** / 発生元 |
   | 決定 (decision) | `### [決定] → Q-n: <the answer>` for an existing question, `### [決定] Q-n: <the choice>` for one the agent made without a prior 未決 (mint the ID now) | refs or mints Q | 理由 / **決定者**: the human's handle, or `エージェント` |
   | 課題 (problem found) | `### [課題] I-n: <one line>` | yes | 症状 or 内容 / 該当箇所 / 今回の変更との関係 |
   | 引継ぎ (handoff) | `### [引継ぎ] H-n: <one line>` | yes | 前提・注意・暫定対応 — what the repo alone would not tell the next person |
   | 報告 (progress) | `### [報告] <date or PR>` | no | 完了したこと / 進行中 / 次 |

   An agent's own decision is recorded as a 決定, not hidden in the 報告: it lands in
   決定済み with `決定者: エージェント`, which is exactly what lets a human see it and
   overturn it. Only choices with a real alternative deserve this — not every variable name.
3. **Route by scope.** When the session has a task issue (Step 0), the task's detail — the
   full 報告 and anything that only matters inside that task — goes as one comment on the
   task issue. The inbox comment then opens with a link to that comment and carries only
   what outlives the task: 引継ぎ, 課題, and the feature-level 未決 / 決定 (those that
   affect other tasks, product behaviour, or the plan). Without a task issue, everything
   goes in the inbox comment.
4. Post **one comment** per destination (per-entry comments notify subscribers each time
   and trip secondary rate limits). Then fetch the inbox body, bump the counters in the
   meta block, append the new `Q-n` / `I-n` / `H-n` lines to the matching lists inside the
   summary region, move any `Q-n` a 決定 closed to 決定済み (and add minted ones there),
   and write the body back with `--body-file`.
5. Report the comment URLs and the IDs assigned.

A 決定 with a human as 決定者 requires that human's answer in this session (or quoted
from where they gave it); otherwise the item stays a 未決 and the triage subcommand is
the place to get it answered.

## summary — fold the comments into the current state

Read `references/summary.md` before running it. Fetch the body and **every** comment
(`--json comments` stops at 100; past that use `gh api --paginate`), then rebuild only the
summary region:

- **最新状況** — what is done, what is in flight (with who / which PR), and the next
  concrete step, in a few lines a returning human can act on. Derived from 報告 entries and
  from 決定 entries that changed direction.
- **未決リスト** — every `Q-n` with no matching 決定, one line each with `判断者` and the
  comment link. Answered ones move to **決定済み** with the answer and the comment link.
  A 決定 given in a human's plain-text comment counts: record it as if it had the header,
  and note that the match was inferred.
- **課題** — open `I-n` (closed ones get struck through with the PR / commit that fixed
  them, or dropped once nothing references them).
- **引継ぎ・注意** — active `H-n`; retire ones a 報告 or 決定 superseded.

Write the region back (read-modify-write), set `summarized-through:` in the meta block to
the last comment's id and date, and post no comment — a summary that announces itself is
one more thing to scroll past. Report the counts and the open-decision list in the chat.

## triage — give the human what they need to decide

Read `references/triage.md` before running it. For every open `Q-n`, human-only first:

```markdown
### Q-3: 認証方式 — OAuth か API key か      判断者: 人間
**要点**: <one paragraph: why this is open, what depends on it>
**選択肢**
- A. OAuth — <what it costs / unlocks>
- B. API key — <what it costs / unlocks>
**推奨**: B — <the reason in one or two sentences>
**必要なもの**: <exactly what the human has to say: a choice, a constraint, a yes/no>
```

Items marked `判断者: エージェント可` get the same block plus a note that the agent can
settle it on request. Present the list and stop — this is the user's turn. When the user
answers, post the 決定 entries (via `post`'s rules: one comment, IDs referenced, decided
items moved to 決定済み). A refusal to decide ("後で") is also a valid answer: leave the
item open and note the date.

Also list, briefly, any 決定済み entries with `決定者: エージェント` that no human has
acknowledged yet — they are decisions the human may want to overturn, and triage is the
moment they will look.

With `triage` and nothing open, say so and show 最新状況 instead of inventing questions.

## What this skill never does

- Edit the body outside its two regions, or delete / rewrite a human's comment.
- Close the inbox issue, or post a 決定 for a human-only item without the human's answer.
- Comment per entry, or comment to announce a summary.
- Switch trackers because a CLI failed — report and stop (2 tries, then hand back).
- Fall back to a guessed inbox when discovery is ambiguous.

## Working alongside other skills

- **agent-flow (github mode)** keeps a tracking issue per flow that closes with its PR.
  Out-of-scope findings and deferred decisions from a flow belong in the feature inbox
  (`post`), with the flow's PR as 発生元.
- **closing** collects residual items at the end of a session. When an inbox exists, its
  handoff comment should be a `post` to the inbox rather than a new unrelated ticket.
- **completion-check** may surface gaps — they are 課題 or 未決 candidates.

Ask once if a detail is genuinely the user's call; otherwise act and say what you assumed.

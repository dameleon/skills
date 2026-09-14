---
name: closing
description: >-
  Close out a stretch of development work (implementation through PR) cleanly: take a
  read-only inventory of the work's state (unpushed commits, PR / check status, uncommitted
  changes, stashes, worktrees, background tasks, cron, artifact watches, temp files), collect
  the residual items the session leaves behind (deferred review findings, existing bugs found
  along the way, unfinished scope), judge whether a handoff record is needed, then act:
  cleanup whose safety is provable from real command output runs without asking, while
  external writes (PR / issue / ticket comments and new tickets on GitHub, Jira, or Backlog)
  and any step that would destroy information git cannot restore are gathered into a single
  approval request — and when that request would be empty, the close finishes on its own.
  Use this whenever the user signals a stretch of work is over and wants it wrapped up —
  "終わりにする", "作業を締める", "後片付けして", "撤収", "closing", "wrap up",
  "この作業終了で", "引き継ぎ残して終わる" — and especially right after a PR is merged,
  handed off, or abandoned. Not a substitute for committing (/incremental-commit) or PR
  creation; it closes work that has already reached its end state.
argument-hint: "[--to github|jira|backlog] [--dry-run]"
---

# Closing — 作業の締めと後片付け

End a development session so that nothing of value is lost, nothing is left running, and the
user is asked only about what is actually theirs to decide:

```
inventory (read-only) → collect residual items → route them → draft the records
    → sort every action into [承認不要] / [承認が必要]
    → 承認が必要 が空なら そのまま実行して報告
      空でなければ 1回だけ聞いて、まとめて実行して報告
```

Three constraints shape every step.

**承認は数を絞る。** Stopping to ask about something whose safety is provable from command
output spends the user's attention for nothing, and a long list of trivial confirmations
trains them to approve without reading — which is exactly when a real risk slips through.
Step 4's split is the load-bearing judgment in this skill: err toward asking and the skill
becomes noise the user clicks past; err toward acting and it eats someone's unpushed work.

**片付けるのは、観測したものだけ。** Every action must trace back to real output from
Step 1. A process, worktree, or temp directory that "should be there" is not evidence, and
acting on an assumed one means deleting the wrong path.

**ツール自身の拒否を安全網として残す。** `ExitWorktree(action="remove")` refuses a worktree
whose state it cannot verify; `git worktree remove` without `--force` refuses a dirty
worktree; `git branch -d` refuses an unmerged branch. Those refusals are why the
corresponding actions can run unattended at all, so never reach for `--force` or `-D` on
your own judgment — doing so removes the very check that made the action safe. The one
sanctioned override is `discard_changes: true` on `ExitWorktree`, and only when Step 1's
inventory already proved the worktree clean (no uncommitted tracked changes, no unpushed
commits).

## Step 0: Parse arguments

From `$ARGUMENTS`:

- `--to github|jira|backlog` — pin the handoff destination, skipping detection (Step 3).
- `--dry-run` — plan only: show what Step 4 sorted into each lane and stop. Nothing runs.
- Any remaining free text describes what the session was about; use it as context for
  Step 2 rather than re-deriving the whole story from the transcript.

If the cwd is not inside a git repository, this skill's scope (implementation-to-PR work)
does not apply. Say so and stop instead of improvising a generic tidy-up.

## Step 1: Inventory (read-only)

Gather the real state before judging anything. Run the reads in parallel where possible;
treat empty output as "none", never as "probably fine".

| What | How |
|---|---|
| Repo root, branch, ahead/behind | `git rev-parse --show-toplevel`, `git status --short --branch` |
| Unpushed commits | `git log --oneline '@{u}..'` — no upstream means *every* local commit is unpushed |
| Uncommitted changes, untracked files | `git status --porcelain` |
| Stashes | `git stash list` |
| Worktrees | `git worktree list --porcelain` |
| PR state | `gh pr view --json number,title,url,state,isDraft,mergedAt,reviewDecision,statusCheckRollup` |
| Merged local branches | `git branch --merged <default-branch>`, plus `git branch -vv` for upstreams |
| Background bash / monitors | the tasks this session started (visible via `/tasks`); stop with `TaskStop` |
| Cron / scheduled agents | `CronList` |
| Artifact watches | `Artifact action:"status"` |
| Temp files | the session scratchpad, plus any workspace directory created during the session (e.g. `<skill>-workspace/`, `.wt/<name>`, ad-hoc scripts left in the repo) |

`TaskStop`, `CronList`, `CronDelete`, `ExitWorktree` are deferred tools in some sessions —
load them with `ToolSearch("select:TaskStop,CronList,CronDelete,ExitWorktree")` before use
rather than concluding the capability is absent. If a capability is genuinely unavailable,
say so in the report; do not claim a process was stopped that you could not reach.

**記憶は観測ではない。** When the session record says something exists — a monitor you
started, a scheduled job — but you cannot see it now (no task handle, the tool is
unavailable, `ps` shows nothing), report it as 未確認 with the reason and leave it in the
user's hands. Do not queue an unattended action against a handle you cannot see: it either
no-ops or hits the wrong target, and both read as "片付けた" in the report, which is worse
than saying you could not check.

Hold the inventory as a short list of facts. It is the evidence base for Steps 4 and 6 — a
fact missing here cannot become an action later.

## Step 2: Collect residual items

Residual items are what a reader of the repo alone would never learn. Sources, in order of
reliability:

1. **This session's own record** — unchecked todo items, plan steps that were dropped, and
   anything explicitly postponed with "後で" / "別PRで" / "今回はやらない".
2. **Review outcomes** — findings triaged as 見送り, 対応不要, or 迷い, and reviewer
   suggestions left unimplemented.
3. **Original scope vs. what shipped** — compare the driving ticket / issue body or the
   approved plan against the PR diff. The gap is unfinished scope.
4. **Incidental discoveries** — bugs and broken behavior noticed while working that the
   change did not touch.
5. **Temporary workarounds** — an env-specific hack, a pinned version, a skipped test.

Then answer one question to decide whether a handoff record is needed at all:

> If someone else picked this work up tomorrow with **only** the repo, the PR, and the
> tracker in front of them, what would they be missing?

Whatever answers that question is the handoff content. If nothing does, the correct outcome
is "引継ぎ不要" stated explicitly — an empty handoff is a real result, and manufacturing
filler comments to look thorough makes the tracker worse and adds an approval the user
did not need to give.

## Step 3: Route each item and draft its record

### Destination detection

First match wins:

1. `--to` argument.
2. A ticket key in the branch name, recent commit messages, or PR title/body
   (`ABC-123` → Jira, a Backlog key → Backlog, `#123` → a GitHub issue in this repo).
3. Project rules naming a tracker (`CLAUDE.local.md`, `.claude/rules/*.md`, `CLAUDE.md`).
4. An issue linked from the PR (`Closes #n`, the PR's `closingIssuesReferences`).
5. Fallback: a GitHub issue in the current repo.

Tool selection per tracker, the exact commands, and body templates live in
`references/trackers.md` — read it before drafting. Never silently fall back to a different
tracker because a CLI is unauthenticated: report that and let the user decide.

### Item type → destination

| Item type | Goes to |
|---|---|
| Deferred in-scope fix (見送った修正) | New ticket, plus a reply on the review thread / PR comment saying it was deferred and where it now lives |
| Existing bug found along the way | New ticket, **not** linked as part of this PR's work — it has its own lifecycle |
| Unfinished scope | New ticket if the driving ticket is being closed; otherwise a comment on that ticket listing what remains |
| Judgment records, assumptions, temporary workarounds | Comment on the PR or the driving ticket. No new ticket |
| Refactor ideas / technical debt with no concrete defect | **Report to the user only.** Deliberately not ticketed — these accumulate as noise tickets nobody closes. Create one only if the user asks |

Search for an existing ticket before drafting a new one so nothing is filed twice (search
commands in `references/trackers.md`). A hit turns a "create" into a "comment on #n".

Write the full body text now, while the worktree and the session context are still intact.
Drafting is free and reversible; it also means Step 6 can proceed even if cleanup has
already removed the files the text refers to.

## Step 4: Sort every action into one of two lanes

This is the step that decides how much of the user's attention this close costs. An action
belongs in the **承認不要** lane only when its precondition was verified by real output in
Step 1 — otherwise it belongs in the other lane.

### 承認不要（そのまま実行してよい）

- **Stopping what this work started**: background bash / monitors (`TaskStop`), cron created
  for it (`CronDelete`), artifact watches (`Artifact action:"unwatch"`). Restartable, so the
  cost of being wrong is a restart. Leave anything that predates this work alone.
- **Temp files under the session scratchpad.** Outside the repo, no history value.
- **Untracked scratch files inside the worktree that the session record accounts for** —
  you created them and can say what each was for. Anything untracked you *cannot* account
  for may be the user's own note (a hand-written memo, a downloaded fixture); that goes in
  the approval lane, because git cannot bring it back.
- **Removing the worktree** when the inventory shows no uncommitted tracked changes, no
  stash belonging to it, no unpushed commits on its branch, **and no open PR on that
  branch**. Inside it: `ExitWorktree(action="remove", discard_changes: true)` — the flag is
  covered by that inventory, and the call runs the environment's `WorktreeRemove` hook
  (e.g. git-wt's delete hook), which raw git would skip. Outside it: `git wt -d <path>` in
  git-wt repos, else `git worktree remove <path>` (no `--force`).
  An open PR means review feedback can still land, and rebuilding
  a worktree to answer it is work this close would have created — so while a PR is open,
  keep the worktree and say so in the report. Keeping is the do-nothing option, so it costs
  no approval; the user can ask for it to go.
- **`git branch -d <name>`** for a branch merged into the default branch and present on
  origin. Never the default branch, never the branch of an open PR.
- **`rmdir` on the container directory** (e.g. `.wt`) once empty — it fails harmlessly if not.

### 承認が必要（1回にまとめて聞く）

- **Every external write** — comment, ticket, review-thread reply. Other people see it and
  retracting it is awkward, so the text and destination are the user's call.
- **Anything git cannot restore**: `git stash drop`, discarding uncommitted changes,
  deleting an untracked file you cannot account for, `rm -rf` on a path outside the
  scratchpad.
- **Anything needing `--force` or `-D`**, or an unproven `discard_changes`. Do not propose
  these unless the user asked; if they did, state exactly what is lost.
- **Remote-side changes**: deleting a remote branch, closing a PR or a ticket.
- **Unpushed commits whose fate is unclear** — push as-is? WIP-commit the fragment first?
  leave the branch alone? Present the options with what each costs; do not pick for them.
- **Any routing you are not confident about** — propose the alternatives instead of guessing
  a destination.

## Step 5: Ask once, or don't ask at all

**If the 承認が必要 lane is empty**, do not manufacture a gate. Execute the 承認不要 lane
(Step 6) and report (Step 7). A close that needed nothing from the user should cost the user
nothing.

**Otherwise**, send one request containing both lanes, and end the turn:

```markdown
## Closing — <work description>

### 現状
- Branch: <name> (<ahead>/<behind>) / PR: #<n> <state> <url>
- 未push: <n>件 / 未コミット: <n>ファイル / stash: <n>件
- 稼働中: <background tasks / cron / watches, or なし>

### 引継ぎ: <必要 — 理由 | 不要 — 理由>

### 承認が必要
1. [comment] <destination> — 要旨: <one line>
   > <the exact body to post>
2. [ticket] <tracker/project> — title: "<title>"
   > <the exact body>
   （既存チケット検索: <query> → ヒットなし / #<n> にコメントへ変更）
3. [判断] <question> — 選択肢: <A: what it costs> / <B: what it costs>

### 承認不要（承認と同時に実行する）
- <action> — 根拠: <inventory fact>
```

The 承認不要 list is shown for visibility, not for evaluation — say so, so the user reads
only the section that needs them. Hold those actions until the same turn as the approved
ones: the user is answering anyway, and an intact worktree is the cheapest way to act on an
answer like "その見送り、やっぱり今やる".

Approval can be partial ("2 は要らない", "コメントだけ") — honor the subset and record what
was skipped in Step 7. With `--dry-run`, stop here regardless of which lane is empty.

## Step 6: Execute

External writes first, in plan order, using the commands in `references/trackers.md`. Record
every resulting URL — a ticket whose URL is not reported is effectively lost.

Then the cleanup, ordered so nothing irreversible precedes its check:

1. Stop what is running (`TaskStop`, `CronDelete`, unwatch).
2. Remove accounted-for scratch files, so the removal does not need a force flag.
3. Remove the worktree, using the criteria and commands from the 承認不要 lane above.
4. `git branch -d` the merged-and-pushed branches; `rmdir` the empty container.

If any step fails, keep going with the independent ones and report the failure with its
actual error. Per the environment-failure rule, retry a broken tool at most twice, then hand
back. A published artifact cannot be deleted through the tool — release its watch and list
its URL in the report so the user can remove it from the gallery.

## Step 7: Report

```markdown
## Closing Summary — <work description>
- **Result**: closed | closed with handoff | 中断 (<reason>)
- **PR**: #<n> <state> <url>
- **引継ぎ**: <不要 | 下記のとおり記録>

### 記録したもの
- [comment] <destination> — <url>
- [ticket] <title> — <url>

### 片付けたもの
- <action> — 完了 | 失敗 (<error>) | スキップ (<reason>)

### 残っているもの（要ユーザー対応）
- <item> — <why it was left, and what to do>

### ユーザーに報告のみ（チケット化していない）
- <refactor idea / debt note>
```

Everything executed appears here, including the 承認不要 lane — minimal approval must not
mean invisible actions, and this list is what makes the split auditable after the fact. The
last two sections are mandatory whenever non-empty: closing silently over a leftover is the
failure mode this skill exists to prevent.

## Abort and handoff rules

Stop and hand back, leaving the workspace as it is, on any of:

- An external write fails, or its tracker CLI is missing / unauthenticated.
- `ExitWorktree(action="remove")`, `git wt -d`, `git worktree remove` or `git branch -d`
  fails. Report the path and command; never escalate to `--force`, `-D`, or an unproven
  `discard_changes` on your own judgment — a git refusal is information (the worktree is
  dirty, the branch is unmerged), so re-check the inventory instead; an `ExitWorktree`
  refusal despite `discard_changes: true` means the tool could not remove it at all.
- A residual item's routing is genuinely ambiguous.
- The user's answer to a 判断 item does not cover what you asked.

On every abort path, still emit the Step 7 report for whatever completed, so a second
`/closing` run can pick up from a known state.

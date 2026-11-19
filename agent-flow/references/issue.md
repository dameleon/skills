# agent-flow: the tracking issue

One GitHub issue is the whole blackboard for a flow. Its **body** is the live control surface, edited in place. Its **comments** are the append-only decision log. Read this before creating, reading, or editing a tracking issue.

## Preflight

All must hold before creating anything. If one fails, say which in one line and stop. Retry once only when the failure looks like a network error.

1. `gh auth status` succeeds.
2. The target repo is the one the PR will open against: `gh repo view --json nameWithOwner,hasIssuesEnabled,defaultBranchRef,viewerPermission`.
3. `hasIssuesEnabled` is `true`.
4. `viewerPermission` is `WRITE`, `MAINTAIN`, or `ADMIN`. The flow creates a label, pushes a branch, and opens a PR, and `gh auth status` succeeding says nothing about this repo. With several accounts logged in, the active one may be the wrong one; say which account is active and stop. Do not switch accounts yourself.

## Body

Fill `templates/ISSUE.md`. Issues have no frontmatter, so the header is a leading HTML comment.

```markdown
<!-- agent-flow:meta
flow: <slug>
branch:
playbook: feature | bug-fix | refactoring | generic | figure-it-out
stage: design | build | verify | ship | closed
pr:
-->
```

| Field | Meaning |
|---|---|
| `flow` | Bare kebab-case slug, no `feat/` or `fix/` prefix. |
| `branch` | Empty until the worktree exists. Then the branch actually checked out there (`git branch --show-current`), normally `<type>/<slug>` with `type` one of `feat`, `fix`, `refactor`, `chore`. |
| `playbook` | Chosen at Frame. Changes only if Design shows the work was misclassified; log that as a decision. |
| `stage` | Where the flow is now. Update it whenever the flow enters a stage, including when it goes back (Verify to Build, Close to Ship). The issue is created at the end of Frame, so the first value is `design`. |
| `pr` | The PR number, filled when it opens. |

Below the meta block, three sections in this order:

- `## 目的` — the goal and the smallest change that meets it. A seed ticket is linked as `関連: #<n>`, never pasted.
- `## 設計` — written at Design, corrected whenever a decision changes it. See `references/design.md` for what it holds.
- `## 手順` — the checklist.

### The checklist

```markdown
## 手順
- [x] 設計
  - [x] Trace the affected subsystem
  - [x] architect for the shape
  - [x] Throughput checkpoint
- [ ] 実装
  - [x] a. <unit>
    - verify: <command or observation> → <what must be seen>
  - [ ] ⏸ 承認: <the irreversible step, in the user's words>
  - [ ] b. <the unit that performs that step>
    - verify: ...
- [ ] 独立検証
- [ ] PR 作成
- [ ] セルフレビュー
- [ ] レビュー修正
```

The six top-level items are fixed and are the same for every playbook. Each is ticked by exactly one stage, so a flow can always reach Close.

| Item | Holds | Ticked by |
|---|---|---|
| `設計` | The playbook's steps that come before code is delegated, one sub-item each | Design, when its sub-items are ticked and 設計 is written |
| `実装` | The units, and any `⏸ 承認` | Build, when every sub-item is ticked and "Before Verify" is done |
| `独立検証` | — | Verify, on `VERIFIED` |
| `PR 作成` | — | Ship |
| `セルフレビュー` | — | Ship |
| `レビュー修正` | One sub-item per accepted finding | Ship, when its sub-items are ticked (immediately, if there are none) |

`references/design.md` says, per playbook, which playbook steps become `設計` sub-items and where the later steps go. A playbook step is never copied as a top-level item.

Rules:

- **Units are the sub-items of `実装`.** One unit per independently checkable result. A ticked unit carries the commit it ended on: `- [x] a. <unit> (3a9f1c2)`. Every unit has a `verify:` line naming what to run or observe and what must be seen. "Tests pass" alone is not a `verify:` unless the tests exercise the changed behavior.
- **`⏸ 承認: ...` is a stop.** It sits immediately before the unit that performs the irreversible step. Only the user's answer ticks it. That unit then runs like any other; when it is an operation rather than code (running a migration, a deploy), this session performs it and records the output.
- **Fix work nests under `レビュー修正`**, one item per accepted finding, each with its own `verify:`.
- **The checklist is always appendable.** New units and fixes are added where they belong. Out-of-scope work never is; it becomes a separate issue.
- **Never write a bare `@name`.** GitHub renders it as a mention and notifies that user. Put any role or handle in backticks.

## Comments: the decision log

A comment records decisions, in pstack's `show-me-your-work` sense: a fork chosen, a unit finished with its result, a pivot or revert and what triggered it, a blocker, a verdict. Not every action.

Post **one comment per boundary**, never one per tick. Every comment notifies subscribers and counts against rate limits.

| Boundary | Comment holds |
|---|---|
| Design recorded | The decisions behind 設計 that the body does not show: what was tried in a prototype, what was ruled out |
| Build finished | One row per unit, plus any pivot or revert |
| Verify verdict | The verdict, the SHA, who verified, the evidence |
| A `⏸ 承認` reached | What is waiting and what the user needs to decide it |
| PR opened | The PR link |
| Review triaged (the self-review, and each later round) | Counts per bucket, and the follow-up issue links |
| Close | What shipped, the PR link, what stays open |

A pivot that changes the design is the one exception to "per boundary": post it when it happens, and correct `## 設計` in the same pass.

Row format, as a Markdown table so it renders:

```markdown
| decision | why | evidence | result |
|---|---|---|---|
| chose a registry over a switch for handlers | three call sites repeat the same branch | `src/handlers/index.ts:12`, commit 3a9f1c2 | tests green |
```

Plain words. Evidence is a pointer (commit SHA, `file:line`, PR number, artifact path), never a paragraph. The log is append-only: a wrong call gets a new row that supersedes it.

## Locating a flow

- **Label and title.** Every tracking issue carries the `agent-flow` label and the title `agent-flow: <human-readable phrase>`. The phrase describes the work; it is not the slug.
  ```bash
  gh label list --search agent-flow --json name --jq '.[].name' | grep -qx agent-flow \
    || gh label create agent-flow --color ededed
  gh issue list --label agent-flow --state open --json number,title,url
  ```
- **Pointer.** Once the worktree exists (before that, only the label finds the flow), `<worktree>/.agent-flow/issue` holds the issue URL on one line. Keep it out of commits through the shared exclude file, not the tracked `.gitignore`:
  ```bash
  EXCLUDE="$(git rev-parse --git-path info/exclude)"
  for p in .agent-flow/ .claude/worktrees/; do
    grep -qxF "$p" "$EXCLUDE" || printf '%s\n' "$p" >> "$EXCLUDE"
  done
  ```

The canonical state is the issue body. The pointer only finds it.

## Read and write

| Operation | Command |
|---|---|
| Read the control surface | `gh issue view <n> --json body --jq .body` |
| Write it back | `gh issue edit <n> --body-file <tmp>` |
| Log | `gh issue comment <n> --body-file <tmp>` |

Write discipline:

- **Single writer.** Only the agent-flow session edits the body. Delegates and seats never do.
- **Read, change one thing, write.** Re-fetch immediately before each edit. Issue bodies have no compare-and-swap, so a stale write silently erases a box a person just ticked.
- **No concurrent body writes**, and no comment per micro-step. Both trip GitHub's secondary rate limits.

## Lifecycle

- **Created at the end of Frame**, with 目的 and the `設計` sub-items. Design then fills 設計 and the units. A flow that dies mid-design is resumable from the issue.
- **Never reuse the seed ticket as the blackboard.** A flow seeded from `#X` gets its own tracking issue with `関連: #X`.
- **Closed by the merge.** The PR body carries `Closes #<n>`. Never close or delete the issue by hand; leaving it open after Close is correct. GitHub closes it only when the PR merges into the default branch. If the PR targets another base, or the flow is abandoned, say so in the Close comment and leave the decision to the user.

## GitHub constraints

| Constraint | Handling |
|---|---|
| No YAML frontmatter in issues | The meta block is a leading HTML comment |
| `@name` renders as a mention | Backtick it |
| Body capped at 65,536 characters | Keep 設計 concise; put a long design in a comment and link it |
| No compare-and-swap on the body | Single writer, re-fetch before each edit |
| Secondary rate limits | Boundary comments only, no concurrent writes |
| Labels must exist before use | Create `agent-flow` if missing; keep all other metadata in the meta block |
| Activity is attributed to the `gh` token's owner | Comments and edits appear as the authenticated user |

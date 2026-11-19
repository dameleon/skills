# agent-flow: the tracking issue

One GitHub issue is the whole blackboard for a flow. Its **body** is the live control surface, edited in place. Its **comments** are the append-only decision log. Read this before creating, reading, or editing a tracking issue.

## Preflight

All must hold before creating anything. If one fails twice, stop and report.

1. `gh auth status` succeeds.
2. The target repo is the one the PR will open against: `gh repo view --json nameWithOwner,hasIssuesEnabled,defaultBranchRef`.
3. `hasIssuesEnabled` is `true`.

## Body

Fill `templates/ISSUE.md`. Issues have no frontmatter, so the header is a leading HTML comment.

```markdown
<!-- agent-flow:meta
flow: <slug>
branch: <type>/<slug>
playbook: feature | bug-fix | refactoring | generic | figure-it-out
stage: frame | design | build | verify | ship | closed
pr:
-->
```

| Field | Meaning |
|---|---|
| `flow` | Bare kebab-case slug, no `feat/` or `fix/` prefix. |
| `branch` | `<type>/<slug>`, with `type` one of `feat`, `fix`, `refactor`, `chore`. |
| `playbook` | Chosen at Frame. Changes only if Design shows the work was misclassified; log that as a decision. |
| `stage` | Where the flow is now. Update it when a stage begins. |
| `pr` | The PR number, filled when it opens. |

Below the meta block, three sections in this order:

- `## 目的` — the goal and the smallest change that meets it. A seed ticket is linked as `関連: #<n>`, never pasted.
- `## 設計` — written at Design, corrected whenever a decision changes it. See `references/design.md` for what it holds.
- `## 手順` — the checklist.

### The checklist

```markdown
## 手順
- [x] 1. Trace the affected subsystem
- [x] 2. architect for the shape
- [x] 3. Throughput checkpoint
- [ ] 4. Delegate code-writing
  - [x] 4a. <unit>
    - verify: <command or observation> → <what must be seen>
  - [ ] 4b. <unit>
    - verify: ...
- [ ] ⏸ 承認: <the irreversible step, in the user's words>
- [ ] 独立検証
- [ ] PR 作成
- [ ] セルフレビュー
- [ ] レビュー修正
```

Rules:

- **Top-level items are the playbook's steps**, in the playbook's order, with a short title each. The playbook's final "Opening a PR" step is replaced by the four tail items (`独立検証`, `PR 作成`, `セルフレビュー`, `レビュー修正`), which every playbook gets.
- **Units nest under the step that delegates code.** One unit per independently checkable result. Every unit has a `verify:` line naming what to run or observe and what must be seen. "Tests pass" alone is not a `verify:` unless the tests exercise the changed behavior.
- **`⏸ 承認: ...` is a stop.** It sits immediately before the step it guards. Only the user's answer ticks it.
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
| Self-review triaged | Counts per bucket, and the follow-up issue links |
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
  gh label create agent-flow --color ededed 2>/dev/null || true
  gh issue list --label agent-flow --state open --json number,title,url
  ```
- **Pointer.** Once the worktree exists, `<worktree>/.agent-flow/issue` holds the issue URL on one line. Keep it out of commits through the shared exclude file, not the tracked `.gitignore`:
  ```bash
  EXCLUDE="$(git rev-parse --git-path info/exclude)"
  grep -qxF '.agent-flow/' "$EXCLUDE" || printf '.agent-flow/\n' >> "$EXCLUDE"
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

- **Created at the end of Frame**, with 目的 and the playbook's steps. Design then fills 設計 and the units. A flow that dies mid-design is resumable from the issue.
- **Never reuse the seed ticket as the blackboard.** A flow seeded from `#X` gets its own tracking issue with `関連: #X`.
- **Closed by the merge.** The PR body carries `Closes #<n>`. Never close or delete the issue by hand; leaving it open after Close is correct.

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

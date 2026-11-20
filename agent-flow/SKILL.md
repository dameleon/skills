---
name: agent-flow
description: >-
  Durable harness that runs a pstack playbook end to end, from design to an opened, self-reviewed PR.
  pstack (the cursor/plugins plugin) supplies how the work is done — playbooks, architect / arena /
  interrogate, real-artifact verification. agent-flow adds a GitHub tracking issue as the blackboard
  (goal, design, step checklist, decision log) that survives sessions and machines, the worktree,
  stops before irreversible steps, and post-PR self-review and triage. One entry point walks Frame,
  Design, Build, Verify, Ship, Close; it starts before the design, so an approved plan is input, not
  a substitute. Use this (and /agent-flow) whenever the user hands over work for agents to design and
  implement through to a PR, or resumes such a flow — "実装フローを回して", "このプランで実装を進めて",
  "設計から実装まで自動で", "タスクをエージェントに渡して実装", "issue #12 のフローを再開". Requires the pstack
  plugin, gh auth, and GitHub Issues. Not for a single quick edit that needs no design or hand-off.
argument-hint: "[task description | tracking issue number or URL]"
---

# Agent Flow

agent-flow is a thin, durable harness around **pstack**. The two are orthogonal:

- **pstack decides how the work is done.** Which playbook fits, how the shape is chosen, how code is delegated, what counts as verified, how a PR reads.
- **agent-flow decides where the state lives and when to stop.** A GitHub tracking issue holds the goal, the design, the step checklist, and the decision log. A worktree holds the code. Stops sit only in front of irreversible steps.

Do not restate pstack here or in a brief. Read its files and follow them; this skill only adds the state, the stage order, and the few overrides listed in `references/pstack.md`.

## Prerequisites

These are assumptions, not modes. If one is missing, say which in one line and stop.

- The **pstack plugin** is installed in Claude Code (`pstack@cursor-plugins`).
- `gh auth status` succeeds, the repo is on GitHub, and Issues are enabled.

Before anything else in a session, resolve pstack and read its adapter and mode skill — `references/pstack.md` has the command and the list of pstack files this skill uses.

## Entry

One entry point, no subcommands.

| Invocation | Meaning |
|---|---|
| `/agent-flow <task>` | Start a new flow at **Frame**. |
| `/agent-flow` | Resume the active flow: one whose `stage:` is not `closed`. If there are several, list them and ask which. |
| `/agent-flow <issue number or URL>` | Resume it if it is a tracking issue. Otherwise it is a seed ticket: start a new flow from it. |

An issue is a tracking issue when it carries the `agent-flow` label and its body starts with `<!-- agent-flow:meta`. Any other issue is a seed ticket, linked from the new flow as `関連: #<n>` and never used as the blackboard.

Find active flows from the `.agent-flow/issue` pointer in any worktree (`git worktree list --porcelain`), else from open issues labelled `agent-flow`. On resume, read the issue body, take the meta block's `stage:` as the position, enter the flow's worktree if it has one (`references/build.md`, "The worktree"), and follow pstack's `playbooks/session-pickup.md`: the trail is authoritative, so do not redo finished work, but check an inherited claim against the real artifact before building on it. A flow at `stage: closed` is resumed only to handle review that arrived later (`references/ship.md`).

## Stages

| Stage | Where | What happens | Who | Details |
|---|---|---|---|---|
| **Frame** | main repo, read-only | Restate the goal, pick the playbook, create the tracking issue | this session | `references/design.md` |
| **Design** | main repo, read-only; the worktree once a bug fix or refactoring must write | The playbook's pre-code steps: trace, shape, verification predicate, decomposition. Recorded in the issue | this session | `references/design.md` |
| **Build** | worktree | Delegate one verifiable unit at a time, check it, tick it | delegates | `references/build.md` |
| **Verify** | worktree | An agent that did not write the code proves the change on the real artifact | verifier | `references/build.md` |
| **Ship** | PR | Open the PR ready for review, post the self-review, triage and fix | delegates + this session | `references/ship.md` |
| **Close** | worktree | Final summary on the issue, then hand cleanup to the `closing` skill | this session | `references/ship.md` |

Read the reference for a stage before acting in it.

**This session is the pstack operator chat.** pstack says the chat that receives `/poteto-mode` owns the playbook, the todo list, and every spawn. Here that chat is the agent-flow session, and the tracking issue's checklist is the todo list. Design is never delegated: pstack keeps the design with the owner, and judgment that needs the session's own model stays in the session.

## Choosing the playbook

Pick at Frame and record it in the meta block's `playbook:`.

| Work | `playbook:` | Leads with |
|---|---|---|
| New or changed behavior | `feature` | the data shape, then `architect` |
| A defect | `bug-fix` | a reproduction on the real surface, then the root cause |
| Structure changes, behavior does not | `refactoring` | a pinned behavior contract |
| None of the above, and small (copy, config, a mechanical edit) | `generic` | nothing — implement, verify, PR, review |
| None of the above, and large, cross-cutting, or unattended | `figure-it-out` | that skill's own framing and workflow design |

`generic` has no pstack playbook file. Its Design is a reduced list (`references/design.md`), and it still gets the Verify stage and the self-review.

## The tracking issue

One issue per flow, one PR per flow. The issue **body** is the live control surface and its **comments** are the append-only decision log. `references/issue.md` is the full contract; the shape is:

```markdown
<!-- agent-flow:meta
flow: add-foo-endpoint
base: main
branch: feat/add-foo-endpoint
playbook: feature
stage: build
pr:
-->

## 目的
<the goal and the smallest change that meets it>

## 設計
<chosen shape and the rejected one, the done predicate, the throughput checkpoint, irreversible steps>

## 手順
- [x] 設計
  - [x] Trace the affected subsystem
  - [x] architect for the shape
  - [x] Throughput checkpoint
- [ ] 実装
  - [x] a. handler for POST /foo
    - verify: `npm test -- foo.handler` exits 0; `curl -X POST :3000/foo` returns 201
  - [ ] ⏸ 承認: 本番 DB へのマイグレーション実行
  - [ ] b. マイグレーションを実行
    - verify: ...
- [ ] 独立検証
- [ ] PR 作成
- [ ] セルフレビュー
- [ ] レビュー修正
```

The six top-level items are the same for every flow, and each is ticked by one stage. The playbook's pre-code steps sit under `設計`. Units of work sit under `実装`, each with a `verify:` line that names what to run and what must be seen. A `⏸ 承認` item is a stop, placed directly before the unit that performs the irreversible step.

There is no local blackboard. `.agent-flow/issue` in the worktree is a one-line locator, nothing more.

## When to stop

These follow pstack: its Autonomy section, `worker.md`, and the one checkpoint `figure-it-out` allows a long run.

- **Proceed** on anything reversible. Show the design in the issue and keep going; do not ask for approval of a plan.
- **Stop at a `⏸ 承認` item.** Design places one in front of every irreversible step: a migration or other write against a real resource, a deploy, deleting data, a force-push to a shared branch, a message to a customer or anyone outside the work. Opening a PR and commenting on this flow's own issue, PR, and follow-up issues are reversible and never get one.
- **A multi-hour run earns one checkpoint.** When Design sizes the work at hours, present the framing and wait once before Build.
- **Session overrides** ("止まらずに", "寝るので進めて") remove the multi-hour checkpoint. They do not remove a `⏸ 承認`.
- A product or preference call that no experiment can settle goes to the user. A fork an experiment can settle gets a prototype instead of a question.

Never merge. Merging stays the user's step, and the issue closes when the PR merges.

## Models and seats

pstack's defaults stand, including the Fable seat in its panels: follow its Subagents section and its per-role lines, mapped through its Claude Code adapter. Pass `model` (and `effort`) explicitly on every `Agent` call, with no exception, and never use `subagent_type: "fork"`.

A panel seat whose model is not a Claude model runs through herdr when this session is inside herdr, so the seat is a real second vendor. Outside herdr it runs on `sonnet`, named explicitly. `references/pstack.md` has the procedure.

## Invariants

- **Once the worktree exists, all writes happen in it.** The session enters it with `EnterWorktree(path=...)` and works from inside, so every command and skill that reads the current directory sees the flow's branch. Before the worktree exists, nothing is written to the repo, and prototypes live in a scratch dir. The worktree is created at the first write the flow needs, which is the reproduction for a bug fix, the pin for a refactoring (both during Design), and the first unit otherwise.
- **Hand-off is by absolute path.** Every brief carries the absolute worktree path and tells the delegate to work inside it.
- **Only this session edits the issue body.** Delegates work, commit, and report. Re-fetch the body immediately before each edit, because a person may have ticked a box in the UI.
- **Finished steps are pushed.** Push the branch after every ticked unit, and after the reproduction or pin, so the flow can be picked up from another machine.
- **The verified SHA is the shipped SHA.** Everything that changes code or history happens before Verify. After the PR opens, history is not rewritten.
- **The author's check is not the verdict.** Verify is done by an agent that did not write the code, at a named SHA. `INCONCLUSIVE` is not a pass.
- **Nothing out of scope stays in the checklist.** A finding the PR will not address becomes its own issue, linked from the PR. The tracking issue closes on merge and takes unchecked boxes with it.
- **Other trackers are not this skill's business.** Do not read from, post to, or route anything to a feature inbox or any issue other than this flow's own tracking issue and its follow-ups.

## Conventions

A project or user rule on any of these outranks the default given here.

- **PR**: opened ready for review, not a draft, with `Closes #<tracking issue>` in the body. Use `.github/PULL_REQUEST_TEMPLATE.md` when the repo has one, else pstack's body shape.
- **Commits**: `/incremental-commit`, run inside the worktree, each verified unit committed before the next starts. It may split one unit into several logical commits.
- **Before Verify**: `/simplify` where pstack says `/deslop`. Default: yes for new logic, refactors, multi-file changes; no for docs, config, a few lines, and say so in the PR body when skipped.
- **Self-review**: `/pr-review-toolkit:review-pr`, read-only, posted to the PR as one review.
- **Seed tickets**: pull with `gh` and distill into 目的; never paste a ticket wholesale.

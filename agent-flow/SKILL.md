---
name: agent-flow
description: >-
  Local, lightweight multi-agent implement workflow. A blackboard inside an isolated git worktree is
  the hand-off channel between agents — on-disk Markdown (PLAN.md / TASKS.md / README.md, the default)
  or a GitHub tracking issue (github mode, for team-visible / cross-machine flows). Turns a design
  (from plan mode, a ticket, or a one-line task) into a checklist subagents execute: design,
  implementation (app + tests + lint + /simplify), testing, PR, post-PR inline review with severity
  triage, and fixes. The execution shape — gate placement plus the engine driving run (subagent /
  goal / ralph) — is decided at design time and encoded in TASKS.md, so run just follows it. The local
  blackboard is disposable (the PR holds history); a github-mode issue persists and auto-closes when
  the PR merges. Subcommands: start (worktree + blackboard + design), run (dispatch pending tasks,
  honoring gates), done (verify pushed / PR exists, then clean up). Use this (and /agent-flow) whenever
  the user hands a design or approved plan to agents for automated multi-step implementation — e.g.
  "実装フローを回して", "このプランで実装を進めて", "タスクをエージェントに渡して実装", "設計から実装まで自動で",
  "githubモードで", "issueで管理して". Not for a single quick edit that needs no worktree, design, or
  task hand-off.
argument-hint: "[start|run|done] [task description or flow slug]"
---

# Agent Flow

A local, multi-agent implementation workflow. The whole flow revolves around a small **blackboard** — three Markdown files that live inside a dedicated git worktree and act as shared memory that agents hand off through:

- **PLAN.md** — design decisions, architecture, and the chosen execution shape.
- **TASKS.md** — a living checklist of tasks, each with a goal and a done-criterion. This is the control surface: `run` reads it to decide what to do next.
- **README.md** — the minimal context for the flow (overview, prerequisites, the *necessary* relations — not the full ticket).

Agents never pass state in memory. They read and write these files on disk, so any agent in any session can pick up where the last one left off, and the flow survives interruptions. When everything is shipped, the worktree (and with it the blackboard) is removed — the durable record is the PR.

## Storage modes — where the blackboard lives

The blackboard's *medium* is a swappable dimension; the control logic (phases, gates, engine, roles, the run loop) is identical across modes. The mode is recorded in the `storage:` field (TASKS.md header in local mode, the issue's meta block in github mode).

| | `local` (default) | `github` |
|---|---|---|
| Blackboard | `.agent-flow/{PLAN,TASKS,README}.md` in the worktree | a single GitHub **tracking issue** (body = control surface, comments = activity log) |
| Read / write the control surface | `Read` / `Edit` the file | `gh issue view --json body` / `gh issue edit --body-file` — **single-writer: only `run` edits the body** |
| Visibility / resumability | local to the machine | team-visible, resumable from any machine |
| `done` | removes the worktree → the blackboard is gone (PR is the record) | removes the worktree; the **issue persists** and auto-closes when the PR merges (never deleted) |
| Needs | nothing | network + `gh` auth + Issues enabled on the repo |

`local` is the default. Choose `github` when the flow should be visible to a team, resumable from another machine, or tracked as a durable issue — the user opts in (e.g. "githubモードで" / "issueで管理"); a flow seeded from a `gh issue` is a natural cue to *offer* it. **All github-mode specifics live in `references/github-mode.md` — read it before any github-mode operation.** The reproduction is faithful (Markdown ↔ Markdown) with a few documented adaptations: YAML frontmatter → a leading HTML-comment meta block; `@role` tags → backticked `` `@role` `` (a bare `@role` renders as a GitHub @-mention); and the body is capped at **65,536 characters** (counted in characters, not bytes), so an oversized PLAN spills to a comment or a linked doc.

## Subcommands

Parse the first argument:

| Arg | Phase | Details |
|---|---|---|
| `start` | Set up the worktree + blackboard, run/serialize the design, seed TASKS.md | `references/start.md` |
| `run` | Dispatch the next pending task(s) to subagents, honoring phase gates | `references/run.md` |
| `done` | Verify the branch is pushed / PR exists, then remove the worktree | `references/done.md` |

**Inference when the first argument is not a subcommand:**
- If there is no active flow (no worktree carries a `.agent-flow/` directory) → treat the arguments as a **task description and run `start`**.
- If an active flow exists and no args were given → continue with **`run`**.
- `done` is normally explicit; `run` proposes it once every task is checked off.

Read the matching reference file before acting — each phase has details that don't belong in this always-loaded overview.

## Runtime (Cursor / Claude Code)

| Concern | Cursor | Claude Code |
|---|---|---|
| Invoke this skill | `/agent-flow` or ask to run agent-flow | `/agent-flow` |
| Move session into worktree | `move_agent_to_root` MCP with the worktree path | `EnterWorktree(path=<worktree>)` |
| Leave worktree session | `move_agent_to_root` back to the main repo path | `ExitWorktree(action="keep")` |
| Dispatch `@role` tasks | `Task` tool (`generalPurpose`, `explore`, `shell`, …) | subagent / Task — use a **valid** type: `general-purpose` (code roles), `Plan` (design), `Explore` (search); prefer `senior`/`generic-coder` if defined. Never use Cursor names or `coder` (run.md). |
| Plan-style design | `SwitchMode` → plan, or `Task` | `Plan` agent |
| Run engine (gateless) | `subagent` only | `subagent` / `/goal` / `/ralph-loop` (ralph-wiggum) |

When dispatching subagents, always pass absolute worktree and blackboard paths. If the session cannot be moved, use `git -C <worktree>` and absolute file paths instead.

## Where the blackboard lives (local mode)

Inside the flow's worktree at `.agent-flow/`:

```
<worktree>/.agent-flow/
├── PLAN.md
├── TASKS.md
└── README.md
```

In **github mode** the control surface lives in the tracking issue, not on disk, and **`start` does not create a worktree** unless the user explicitly asks (the issue needs no local checkout) — the worktree is created at `run`, when code work begins. Once it exists, `.agent-flow/` holds only a one-line `issue` pointer so a fresh `run`/`done` can rediscover the flow from it; until then the flow is rediscovered from the tracking issue itself (the `agent-flow` label / its URL). See `references/github-mode.md`. Either way the directory is excluded the same way.

Keep it out of commits without touching the repo's tracked `.gitignore` (which would itself be a change to review). Add it once to the shared exclude file — this covers the main repo and every worktree, and is idempotent:

```bash
EXCLUDE="$(git rev-parse --git-path info/exclude)"
grep -qxF '.agent-flow/' "$EXCLUDE" || printf '.agent-flow/\n' >> "$EXCLUDE"
```

## Worktree resolution (precedence)

The implementation work is isolated in its own worktree. Pick the creation mechanism in this order — a project that wraps `git worktree` (to copy `.env`, enforce a tool, etc.) will leave the worktree unbootable if you bypass it:

1. **Project rule** — `.cursor/rules/*worktree*`, `.claude/rules/*worktree*`, `CLAUDE.md` / `AGENTS.md` worktree sections, or a repo tool like `git wt`.
2. **User rule** — a global convention (e.g. worktrees under `.wt/<flat-name>`, base branch from the repo's default).
3. **Fallback** — raw `git worktree add -b <branch> <path> <base>`.

The **slug is a bare kebab name** with no `feat/` / `fix/` prefix — the prefix is added only when forming the branch. Derive the branch as `<type>/<slug>`, where `<type>` is `fix` for bug work and `feat` for a feature.

Default path when no rule applies: `<repo>/.wt/<slug>` (flat name, no slashes); branch `<type>/<slug>` from `origin/<default-branch>`.

## The TASKS.md schema (the control surface)

TASKS.md is plain Markdown — a checklist, not JSON. Every operation `run` needs is a grep away (find the next `- [ ]`, detect gates, check for completion), and a checklist is the most natural thing for many agents to append to without breaking it.

```markdown
---
flow: add-foo-endpoint
branch: feat/add-foo-endpoint
pr:                       # filled in after the PR is opened
phase: 2                  # pointer to the current phase
engine: subagent          # subagent (default) | goal | ralph — goal/ralph only on a gateless flow
storage: local            # local (default) | github — see "Storage modes"
---
# TASKS

## Phase 1: 詳細設計  <!-- gate: review -->
- [x] API スキーマ確定 @design
  - goal: エンドポイントと型が PLAN.md と一致する
  - done: PLAN.md の API 節が更新済み

## Phase 2: 実装  <!-- gate: none -->
- [ ] ハンドラ実装 @implement (depends: Phase1)
  - goal: 正常系・異常系を満たす
  - done: ユニットテストが green
- [ ] ブラウザ動作確認 @test
```

This same schema drives github mode, with two transcription rules (`references/github-mode.md`): the header moves into a leading HTML-comment meta block in the issue body (no YAML frontmatter in issues), and every `@role` is backticked — `` `@implement` `` — so GitHub doesn't render it as an @-mention. Phase headings, gate markers, checkboxes, and `goal:`/`done:` are unchanged.

Reading rules:
- `storage:` (header) — the blackboard medium: `local` (default, on-disk files) or `github` (a tracking issue). See "Storage modes."
- `engine:` (header) — what drives `run`: `subagent` (default), `goal`, or `ralph`. See "Choosing the engine." `goal`/`ralph` are valid only on a gateless flow.
- `## Phase N: <name>  <!-- gate: review|approve|none -->` — a phase boundary and its gate. `run` **stops at a gate** (`review` = run a review; `approve` = ask the user) and continues through `none`. **A gateless flow runs end-to-end** — whether by the `subagent` loop running straight through or by a `goal`/`ralph` engine. This is how the design's chosen execution shape becomes the runtime behavior.
- `- [ ] <task> @<role>` — a task and which agent role handles it: `@design`, `@implement`, `@test`, `@refactor`, `@pr`, `@pr-review`, `@address-review`, `@review`, `@fix`. `[x]` = done. (Roles are spelled out in `references/run.md`: `@implement` carries the app→test→lint→`/simplify` inner loop; `@pr-review` generates our own review on the open PR; `@address-review` responds to externally-authored PR review; `@review` is the pre-PR diff/design review.)
- `goal:` / `done:` — the task's goal and its objective completion criterion. `done:` is required; `goal:` is recommended but may be omitted when `done:` alone is self-explanatory (e.g. a verification `@test` task).
- `(depends: ...)` — an ordering hint; tasks are otherwise taken top-to-bottom.

A **phase is a gate-delimited group of tasks** — it may hold any number of `@role` tasks, and its gate fires *when the phase completes*: the checkpoint you pass before advancing to the next phase. So `gate: review` on a 詳細設計 phase means "review the finished design before implementing"; `gate: approve` on an 実装 phase means "get human sign-off after implementing, before the PR phase." Put the work you want checkpointed inside the phase; its gate guards leaving it. A true one-pass flow is a **single `gate: none` phase** holding every task — its gate never fires, so the loop runs straight through:

```markdown
## Phase 1: 実装  <!-- gate: none -->
- [ ] 文言を i18n キーへ置換 @implement
  - done: 既存テストが green のまま
- [ ] テスト確認 @test
  - done: ユニットテスト green
- [ ] PR 作成（draft / PR テンプレ準拠） @pr
  - done: ドラフト PR が開かれ、ヘッダ pr: が埋まる
```

In a gateless flow `@pr` opens a draft PR with no human stop — that is the intended consequence when the user has accepted shipping without a checkpoint.

### Choosing gates — the design's main decision

Where you place gates is *the* control-flow decision, and it should follow the work's risk, not the user's surface phrasing:

- **`approve`** — stop for a human. Use before a step with an **irreversible side effect**: a schema/data migration run against a real resource, a deploy, an external publish/send — or when the user explicitly wants to sign off in person ("見せて確認したい" / "マージ前に確認"). Opening a *draft* PR is **not** irreversible (it can't merge itself), so "about to open a PR" does not by itself warrant an `approve`.
- **`review`** — run an automated / LLM review (e.g. the `cross-review` skill) and fold findings back as `@fix` tasks; no human stop. Cues like "レビューにかけて" / "指摘がほしい" map here — but mind the who-acts note below: a first-person "レビューしたい" is `approve`, not `review`.
- **`none`** — no checkpoint, the loop flows straight through. Use for pure-additive, low-risk work whose `done:` criteria are objective (the tests turn green).

Disambiguate by *who acts*, not the keyword: a first-person "自分が見たい / 確認したい / 設計をレビューしたい" is a human checkpoint → `approve`; "レビューにかけて / 指摘がほしい" (have it reviewed by a tool or another agent) → `review`.

**Prefer an externally-observable checkpoint over a locally-blocking one.** An `approve` gate before the PR stops the run session *inside the worktree* — nothing pushed, nothing visible; if the user steps away, finished work sits undetectably idle. A pushed **draft PR** is the opposite: externally visible (GitHub, CI, notifications) and safe, because a draft can't merge itself. So **when the user hasn't pinned this down, default to a gateless flow that runs straight through to a draft PR, then self-reviews it**: a single `gate: none` implementation phase (`@implement` → optional `@test` → `@pr`), then a `gate: none` phase with one `@pr-review` task, then a `gate: none` 修正 phase for the `@fix` tasks it appends. The checkpoint is the open, self-reviewed draft PR — one human touchpoint, relocated from a silent local prompt to an observable artifact. Reserve `approve` for the irreversible-side-effect steps above. (A trivial change may drop the `@pr-review` phase; a fully gateless flow with no `@pr-review` is also eligible for the `goal`/`ralph` engines.)

Phase boundaries follow checkpoints, not code layers: group everything a single gate should guard into one phase, and don't split by layer (API / front / test) when no checkpoint sits between the layers. The flow's terminal artifact is a *draft* PR — merging is the user's manual step after `done`, so the draft PR itself is the default pre-merge checkpoint; add an `approve` gate only to guard an irreversible step *before* the PR opens.

**Two review shapes.** A *pre-PR* review fits the `gate: review` checkpoint: when a phase completes, `@review` runs `cross-review`/`codex-review` on the diff or finished design and folds findings into `@fix` — no PR, no human stop. A *post-PR* review is a `@pr-review` task placed in its own `gate: none` phase after `@pr` (a task, not a gate — so it never double-runs with `gate: review`): it runs `pr-review-toolkit:review-pr`, posts the findings to the open PR as inline comments, and triages by severity — must-fix → in-scope `@fix`; clearly out-of-scope → a follow-up issue (it must leave TASKS.md, which `done` destroys); ambiguous → ask the user. **This is part of the default shape** (above): the draft PR's self-review is what makes the PR a real checkpoint, not just an artifact — drop the `@pr-review` phase only for a trivial change or when the user declines comments on the PR ("PR コメント要らない"). Its conditional ask is an interior human touchpoint, but by then the PR is already open and observable, so it never hides finished work — a flow that includes `@pr-review` runs under `subagent` (which is therefore the default engine). Responding to *externally-authored* review on the PR — a human / Copilot reviewer — is a separate role, `@address-review` (see `references/run.md`); since external review usually lands after the flow would `done`, it may mean keeping the worktree or re-attaching one.

### Choosing the engine — what drives `run`'s loop

Once the gates are placed, decide *what mechanism* drives the loop. This is a design-time consideration that crystallizes into an **applicability check** the moment a flow is set up: for each engine, ask "does it apply here?" in order — the answer falls out of the shape you just chose. Engines are Claude Code mechanisms; under Cursor, fall back to `subagent`.

1. **Any gate present (or an `@pr-review` task)?** A flow with a mid-way `review`/`approve` gate — or a `@pr-review` task, whose severity triage can ask the user — **must** use `subagent`: `/goal` and `ralph` are whole-session convergence loops that cannot stop at an interior checkpoint. Since `@pr-review` is in the default shape, the **default engine is `subagent`**; only a gateless flow with no `@pr-review` is eligible for `goal`/`ralph`.
2. **A single end-state the session can *demonstrate in its own transcript*?** (tests exit 0, no `- [ ]` left in TASKS.md, a queue drained, a size budget met). If not → `subagent`.
3. **Character of the work:** heterogeneous tasks / worth parallelizing / fresh context per task helps → **`subagent`** (the default). Migration / backlog-drain / "iterate until the condition holds," stop when an evaluator confirms → **`goal`**. Iterative self-verifying refinement (greenfield, tighten-until-clean), stop on a fixed phrase → **`ralph`**.

**The engine choice rewrites the work instruction — that *is* the check's payoff, not a side effect:**

| Engine | `run` invokes | The instruction becomes |
|---|---|---|
| `subagent` (default) | the per-task dispatch loop | each task's `@role` + `goal:` / `done:` (unchanged) |
| `goal` | `/goal "<condition>"` in the worktree session | a single **completion condition** phrased around *demonstrable* output (the evaluator reads only the transcript) + constraints + a turn cap (`or stop after N turns`) |
| `ralph` | `/ralph-loop "<prompt>" --completion-promise "<phrase>" --max-iterations <n>` | a **re-feed prompt** ("read TASKS.md, do the next `- [ ]` in `<worktree>`, commit, then stop; if none remain output `<phrase>`") + the exact phrase + a max-iterations cap |

Record the pick in TASKS.md's `engine:` header and explain it (with the exact condition / phrase + cap for `goal`/`ralph`) in PLAN.md's 制御フロー section. The blackboard pairs especially well with `ralph`: TASKS.md *is* the across-iteration progress state, so each re-feed reads it, does one item, ticks it, commits — no "what's left?" drift. **Default when nothing forces the choice: `subagent`.**

## Invariants that keep the flow correct

- **The worktree is the default workspace.** Once a flow's worktree exists, *every* operation defaults into it — the run session itself, subagent dispatches, ad-hoc edits, commits, tests — and never touches the main repo / default branch unless the user explicitly directs otherwise. `start` enters the worktree, `run` re-enters it before any write, and a mid-flow request stays in it. (Design done *before* the flow existed — Mode A — is naturally outside; the rule binds from worktree-creation onward, and the skill imposes no fixed order between designing and starting the flow.) This matters doubly for the `goal` / `ralph` engines, which run in the *current* session: that session must be inside the worktree first. **github mode defers the worktree**: `start` skips creating it unless the user explicitly asks (the issue is the blackboard and needs no checkout), so it first comes into being at `run` when code work begins — see `references/github-mode.md`.
- **Hand-off is by absolute path.** Every subagent dispatch carries the absolute worktree path and the absolute blackboard paths, and tells the subagent to operate inside the worktree (start with the worktree as cwd, or use `git -C <worktree>`). Subagents inherit the session cwd, but being explicit means a stray `git commit` can never land on the wrong branch.
- **TASKS.md is always updatable.** Mid-implementation or mid-review, append the next task to the right phase. The living checklist *is* the plan; re-read it after every task because it may have grown.
- **Cleanup is guarded.** `done` removes the worktree (and the blackboard) only after confirming the work is committed, pushed, and a PR exists. The blackboard is disposable precisely because the durable history is the PR; never destroy un-pushed work. **In github mode the blackboard is the tracking issue, which is *not* disposable**: `done` removes only the worktree and leaves the issue open (it auto-closes when the PR merges); never delete the issue.
- **Only `run` writes the github-mode body.** When `storage: github`, the tracking-issue body is single-writer — only the `run` orchestrator edits it (read-modify-write, re-fetching immediately before each edit since a human may have toggled a checkbox in the UI). Subagents do work, commit, and *report back*; they never edit the body, though they may post comments. This avoids lost-update races (issue bodies have no compare-and-swap) and respects GitHub's secondary rate limits.

## Project / user conventions to honor

- PRs: create as **draft** and use `.github/PULL_REQUEST_TEMPLATE.md` if present.
- Commits: use the `/incremental-commit` skill if available, run from inside the worktree.
- Tickets (when a design is seeded from one): use the project's preferred CLI (`gh`, `jira`, `backlog`) rather than pasting the whole ticket — README.md keeps only the necessary relations.
- Reviews: `@pr-review` uses `pr-review-toolkit:review-pr` for findings, then posts them as PR inline comments via `mcp__github` (`add_comment_to_pending_review` → `pull_request_review_write`) or `gh api .../pulls/{n}/comments` — review-pr itself does not post. Pre-PR review uses `cross-review` / `codex-review`.
- Follow-ups: out-of-scope findings become tracking issues (`github-issues` skill, else `gh issue create`) linked from the PR — never left as un-checked TASKS.md items, which `done` removes with the blackboard. In github mode they are still *separate* issues (linked from both the PR and the tracking issue), not stray unchecked boxes in the tracking issue, which closes when the PR merges.
- GitHub mode (`storage: github`): the medium-specific procedure — preflight, creating the tracking issue, the body layout, read/write primitives, the comment policy, and engine interplay — lives in `references/github-mode.md`. Read it before any github-mode `start` / `run` / `done`.

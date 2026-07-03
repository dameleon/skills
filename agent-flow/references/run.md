# agent-flow: run

Execute the blackboard: drive the next pending work to completion, keep TASKS.md current, and stop at gates. *How* it drives depends on the flow's engine.

## Step 1 — Locate and load the flow

- If a slug was given, target that flow. Otherwise discover active flows: `git worktree list --porcelain`, and for each worktree check `.agent-flow/` — `TASKS.md` (local) or an `issue` pointer (github). If several match, list them (by `flow:` header) and ask which.
- Switch into the worktree if the session is not already inside it (**Cursor**: `move_agent_to_root`; **Claude Code**: `EnterWorktree(path=<worktree>)`). All run work happens inside the worktree (SKILL.md invariant) — and the `goal`/`ralph` engines below run in *this* session, so being inside the worktree first is mandatory for them, not just tidy.
- Read PLAN.md, README.md, and TASKS.md. The header's `phase` is your current position; the header's **`engine`** (default `subagent`) selects how to drive the loop in Step 2; the header's **`storage`** (default `local`) selects where you read/write that control surface.
- **If `storage: github`**, the control surface is the tracking issue, not files: read it with `gh issue view <n> --json body` and parse the body exactly as TASKS.md (the meta block carries `phase`/`engine`/`pr`). Tick boxes and bump the meta by editing the body (`gh issue edit`), under the single-writer + re-fetch discipline. All github-mode read/write/comment/engine specifics are in `references/github-mode.md` ("run (github mode)"); the per-`@role` dispatch logic below is otherwise unchanged — subagents work in the worktree and report back; **only `run` edits the issue body**.

## Step 2 — Drive the loop by engine

### engine: `subagent` (default)

Repeat until you hit a gate or run out of pending tasks:

1. **Pick the next task** — the first `- [ ]` in the current phase (respect `depends:`; otherwise top-to-bottom). **Then check idempotency before dispatching:** a prior pass, a `goal`/`ralph` iteration, or a crash after commit-but-before-tick can leave a code task's `done:` *already* satisfied with the box still `- [ ]`. Verify against the worktree (`git -C <worktree> log/diff`, or re-run the `done:` check); if it already holds, **tick `[x]` (committing only any stray uncommitted changes) and skip the dispatch.** Re-dispatching a done task only yields a subagent reporting "nothing to do / didn't edit" — the single most common empty-handed report, and not a failure to act.
2. **Dispatch it** to a subagent chosen by its `@role`:
   - `@design` → plan-style agent (**Cursor**: `SwitchMode` plan or `Task`; **Claude Code**: `Plan` agent); refines PLAN.md.
   - `@implement` → general implementation agent (`Task` / subagent) writing code in the worktree. It carries the **implementation inner loop**, run *before* the box is ticked: **(0) detect the project's test + lint commands up front (`package.json` scripts, `Makefile`, `CLAUDE.md` conventions); if neither can be found, stop and report rather than write throwaway code or tick (honor the 2-try environment-block rule);** (1) write the app code; (2) write / adjust tests; (3) run test + lint, iterating until both are green — if they cannot be made green, stop and report rather than tick; (4) run `/simplify` on the diff (default; emit a separate `@refactor` task only when the design pre-declared a cleanup checkpoint) and **re-run test + lint**, keeping them green; (5) tick `[x]` and commit with `/incremental-commit`. So a coarse `@implement` task's `done:` reads like "app + tests written, test + lint green, diff simplified" — the cycle lives in the role, not in extra TASKS.md rows.
   - `@refactor` → run `/simplify` (or a refactor subagent) on the worktree diff: quality-only, behavior-preserving, and it must leave test + lint green. Use a standalone `@refactor` task only when the design wants the cleanup checkpointed on its own; otherwise it is already part of the `@implement` loop above.
   - `@test` → agent that runs the project's **tests and lint** (plus typecheck / static checks where they exist) — all green is the done-criterion — or drives the browser via `chrome-devtools` / `cursor-ide-browser` / `agent-browser` MCP for UI checks.
   - `@pr` → open a **draft** PR with `gh`, using `.github/PULL_REQUEST_TEMPLATE.md` if present; write the number back into the TASKS.md header `pr:`.
   - `@pr-review` → runs **after the PR is open** (needs the header `pr:`). Three steps: **(a) findings** — dispatch `pr-review-toolkit:review-pr` over the PR diff to get `file:line` + severity findings (it returns a report, it does not post); **(b) post** them to the PR as **inline review comments** — open a pending review, attach one comment per finding that has a `file:line` anchor (`path` + `line` + body), submit as `COMMENT`, via `mcp__github` (`add_comment_to_pending_review` → `pull_request_review_write`) or `gh api repos/{owner}/{repo}/pulls/{n}/comments` with `commit_id = git -C <worktree> rev-parse HEAD` (the PR's pushed head — if the worktree is ahead of the remote, push first so the SHA anchors). A finding with no `file:line` (architectural / general) goes in the review summary body, not as an inline comment. Posting and triage are orthogonal — every `file:line` finding is posted inline regardless of its triage bucket. **(c) triage** — in-scope (must-fix / critical, and minor nits in the PR's own changed code) → append `@fix` tasks to the fix phase (create a `## レビュー修正  <!-- gate: none -->` phase after `@pr` if none exists); clearly out-of-scope → a follow-up issue (`github-issues` skill, else `gh issue create`) linked from the PR (post a PR comment containing the issue URL); **ambiguous → ask the user** which bucket. On a non-GitHub forge, substitute its review-comment mechanism.
   - `@address-review` → respond to **externally-authored** review on the open PR (a human reviewer, Copilot, a GitHub review) — distinct from `@pr-review`, which generates *our own*. Steps: **(a) fetch** the PR's unresolved review threads (`gh pr view <n> --json reviews,comments`, `gh api repos/{owner}/{repo}/pulls/{n}/comments`, or `mcp__github__pull_request_read`); **(b) triage** each by the same policy as `@pr-review` — in-scope → `@fix` in the fix phase; clearly out-of-scope → a follow-up issue linked from the PR; ambiguous → ask the user; **(c)** after the `@fix` work is pushed, reply to / resolve each addressed thread. Needs a worktree on the PR branch — external review usually arrives *after* the flow would `done`, so re-attach one if it was already removed (see `done.md`).
   - `@review` → **pre-PR** diff / design review: invoke a review skill (`cross-review`, `codex-review`) on the worktree diff; translate findings into `@fix` tasks appended to TASKS.md. (No PR involvement — use `@pr-review` to review *on* an open PR.)
   - `@fix` → apply an agreed fix; if it answers a `@pr-review` or `@address-review` comment, reply to / resolve that PR review thread after pushing. It may append further follow-ups.

   **Cursor**: use the `Task` tool with an appropriate `subagent_type` (`generalPurpose`, `explore`, `shell`, …).

   **Claude Code**: dispatch with a *valid* `subagent_type` — `general-purpose` for code-producing roles (`@implement` / `@fix` / `@refactor`), `Plan` for `@design`, `Explore` for read-only search. These built-ins always exist. If the user has defined `senior-coder` / `generic-coder` subagents (`~/.claude/agents/`), **prefer** them for code-producing roles — `generic-coder` by default, `senior-coder` for design-heavy or cross-cutting work. **Never carry a Cursor type name (`generalPurpose`, `explore`, `shell`) or a guessed name like `coder` into a Claude Code dispatch** — an unknown `subagent_type` is a *hard error*, not a silent no-op; on `Agent type '…' not found`, fall back to `general-purpose`.

   The dispatch prompt always includes: the **absolute worktree path**, the **absolute blackboard paths**, the task's `goal` and `done`, the instruction to **work inside the worktree** (cwd = worktree, or `git -C <worktree>`), and the instruction to **update TASKS.md** when finished — tick the box `[x]`, append any newly-discovered tasks to the right phase, and — **if the task produced file changes** — **commit the work** with `/incremental-commit`. A verification-only role (`@test` running tests/lint, `@review` reading a diff) produces no commit: it reports its result and ticks on that. This explicitness is why a subagent's `git commit` can never stray onto the wrong branch. (In **github mode** the subagent **reports back instead of editing the blackboard** — only `run` ticks the box, by editing the issue body; see `references/github-mode.md`.)

3. **Confirm the task's changes are committed** — the code-producing subagent commits inside its own loop (`/incremental-commit`, in the worktree); if it returned changes uncommitted, commit them here. One commit per task — never double-commit. **If a subagent reports it made no changes,** don't re-dispatch reflexively: confirm against the worktree — if the task's `done:` already holds, just tick `[x]`; if it stopped on a *red* test/lint, sanity-check that the failure is real and not tooling noise (a wrapper/proxy mis-parsing a command whose raw exit is 0) before accepting "can't make it green" — noise is an environment block (2-try rule), not a code defect to fix.
4. **Re-read TASKS.md** — it may have grown. Re-evaluate what is pending.

Then honor gates (Step 3).

### engine: `goal`

The flow is gateless with one demonstrable end-state (chosen at start, recorded in PLAN.md 制御フロー). Drive it with `/goal` in this in-worktree session instead of dispatching per task:

1. Issue the recorded completion condition: `/goal "<condition>"`. The evaluator reads only the transcript, so the condition must be phrased around output the session *shows* — e.g. no `- [ ]` left in `.agent-flow/TASKS.md`, tests exit 0, `gh pr view` resolves. Keep the turn cap (`or stop after N turns`).
2. As the loop runs, tick TASKS.md and commit with `/incremental-commit`; the `@pr` work (open the draft PR, write back `pr:`) **must** be part of the condition, or the goal clears before the work ships.
3. When the goal clears, go to Step 4. If it stalls or hits the turn cap without clearing, `/goal clear`, report, and leave the worktree intact.

### engine: `ralph`

Gateless, iterative self-verifying work. Drive it with the `ralph-loop` plugin (Runtime table) using the prompt / phrase / cap recorded in PLAN.md:

1. `/ralph-loop "<re-feed prompt>" --completion-promise "<phrase>" --max-iterations <n>`. The prompt points at `.agent-flow/TASKS.md` so each iteration reads it, does the next `- [ ]` in the worktree, commits, and stops — emitting the exact `<phrase>` only when none remain (and the draft PR is open).
2. Completion matching is exact-string, so the prompt and `--completion-promise` must use the identical phrase; always set `--max-iterations` as the backstop.
3. On the completion phrase, go to Step 4. If it loops without progress or hits the cap, `/cancel-ralph`, report, and leave the worktree intact.

## Step 3 — Honor gates (`subagent` engine)

When a phase's tasks are all done, evaluate that phase's gate *before advancing* to the next phase — the gate is the checkpoint at the phase's completion:

- `gate: none` — advance into the next phase and keep looping.
- `gate: review` — run the review step on what the phase produced, surface the result, and turn findings into `@fix` tasks. Continue once they are handled.
- `gate: approve` — stop and ask the user to approve moving on. Wait for their response.

**In github mode, post a boundary comment when you evaluate a gate** (what the phase produced; for `approve`, that you're waiting) — this is the one place gate logging belongs, and it's why comments are boundary-only, not per tick (`references/github-mode.md`).

Update the header `phase:` as you cross boundaries. **If the flow has no gates at all (every boundary is `none`), the loop runs to completion in one go** — the one-shot behavior decided at design time. (A `goal`/`ralph` engine is gateless by construction — no gate ever fires, so there is no interior checkpoint to honor, however many `none` phases it spans.)

## Step 4 — Wrap up the pass

When the current phase (or the whole flow) has no remaining `- [ ]`:

- (`subagent`) If tasks remain in later phases behind a gate you just satisfied, continue.
- If every task is done, **ensure the branch is pushed** — push if the loop hasn't already; this holds for every engine, since `done`'s guard refuses to clean up an un-pushed branch — then suggest `agent-flow done` (e.g. `/agent-flow done`).

If a dispatched subagent fails or returns something ambiguous, a `goal` stalls, or a `ralph` loop hits its cap without converging, stop and report rather than guessing — leave the worktree intact so the user can inspect.

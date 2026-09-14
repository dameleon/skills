# agent-flow: start

Set up an isolated worktree, lay down the blackboard, and get the design into it. The design may already exist (you just left plan mode, or worked it out in this conversation) or may need to be produced now — handle both.

## Step 1 — Decide the design mode

Judge from the conversation:

- **Mode A — serialize an existing design.** A firm design is already in context (an approved plan from plan mode, or a design hashed out in this session). Your job is mostly to *transcribe and structure* it into the blackboard, not to redesign.
- **Mode B — design first, then serialize.** You were invoked cold with a task description (or a ticket reference). Run a real design step first.

If it is genuinely unclear which mode you are in, ask the user one short question ("既に設計は固まってる? それともここから設計する?") rather than guessing. A bare ticket reference or a one-line task with no prior design discussion is unambiguously Mode B — don't ask, just design.

### Mode B design step

Produce a design good enough to seed concrete tasks:

- Clarify the goal and constraints with the user where they are ambiguous.
- Explore the codebase for the affected areas (read the relevant files; a subagent is fine for breadth).
- If the seed is a ticket, pull it with the project's CLI (`gh issue view`, `jira`, `backlog`) and distill — do not paste it wholesale.
- For non-trivial work, the `Plan` agent or the `prd` skill can produce the design; converge with the user on the design and the execution shape **before `run` begins**. The blackboard you write in Step 5 is a proposal — write it first and get agreement at Step 6; you do not need to confirm before writing it.

The execution-shape decision (gates **and** engine) is its own step below — it applies whether the design came from Mode A or Mode B.

## Step 2 — Decide the execution shape: gates + engine

With the design in hand (serialized from Mode A or just produced in Mode B), make the two coupled control-flow decisions. Full rationale is in SKILL.md ("Choosing gates" + "Choosing the engine"); the procedure:

1. **Place the gates** by the work's risk — `approve` (human stop), `review` (automated review → `@fix`), `none`. **Default to a gateless flow that runs straight through to a draft PR, then self-reviews it** (`gate: none` 実装 → `gate: none` `@pr-review` → `gate: none` 修正): the open, self-reviewed draft PR is the checkpoint — an externally-observable artifact, not a silent local stall. Reserve `approve` for a step with an **irreversible side effect** (real migration / deploy / external send); opening a *draft* PR is not irreversible. Drop the `@pr-review` phase only for a trivial change or when the user declines PR comments. See SKILL.md "Choosing gates" and Step 5.
2. **Run the engine applicability check.** For the resulting shape, decide what drives `run`:
   - Any gate present, **or an `@pr-review` task** (its triage can ask the user) → **`subagent`** (forced; `goal`/`ralph` can't stop at an interior checkpoint). Since `@pr-review` is in the default shape, `subagent` is the default.
   - Gateless **and** one end-state the session can demonstrate in its transcript → eligible for **`goal`** (converge-until-condition: migration, backlog-drain) or **`ralph`** (iterative self-verifying refinement). Otherwise **`subagent`**.
   - Nothing forces it → default **`subagent`**. (Under Cursor, always `subagent`.)
3. **If you picked `goal` or `ralph`, draft the engine-shaped instruction now** (it replaces per-task dispatch as run's driver; you write it into PLAN.md in Step 5):
   - `goal`: a completion condition around demonstrable output, e.g. "the latest `cat .agent-flow/TASKS.md` shows no `- [ ]`, `npm test` exited 0, and `gh pr view` resolves" + a turn cap.
   - `ralph`: a re-feed prompt ("read .agent-flow/TASKS.md, do the next `- [ ]` in `<worktree>`, commit; if none remain, output `<PHRASE>`") + the exact `<PHRASE>` + `--max-iterations`.
   - Size the cap (turn cap / `--max-iterations`) to the task count plus a small margin — e.g. ~12 for 8 tasks. It is a runaway backstop, not a target; the completion condition / phrase is what should normally stop the loop.

The pick lands in the TASKS.md `engine:` header and PLAN.md 制御フロー (Step 5).

## Step 3 — Derive the slug and resolve the worktree

- `slug`: a short kebab-case name for the flow, with no `feat/` / `fix/` prefix (e.g. `add-foo-endpoint`). Derive it from the work's subject — the ticket title in Mode B, the design's subject noun in Mode A.
- Resolve the worktree mechanism per SKILL.md "Worktree resolution": Claude Code hands creation to the harness (`EnterWorktree(name=<branch>)`); Cursor follows the precedence (project rule → user rule → raw `git worktree`).
- Compute the branch (`<type>/<slug>` from `origin/<default-branch>`). On Cursor also compute the path (default: `.wt/<slug>` under the repo's convention); on Claude Code the path is whatever the harness reports.
- **Refuse to clobber existing state.** If the branch already exists, or a worktree is already registered for it (`git worktree list --porcelain`), stop and tell the user to remove or reuse the existing worktree/branch rather than reusing it silently.

**In github mode, defer this.** Resolve the slug and the worktree *mechanism* (you will need them at `run`), but **do not create or enter the worktree** unless the user explicitly asked to work locally now — github mode's blackboard is the tracking issue, which needs no checkout, and the machine that implements may differ from this one. `run` creates the worktree when the first code-producing task begins (`references/github-mode.md`).

In **local mode** (and github mode only when explicitly asked), create the worktree, then switch the session into it so subsequent file and Bash operations target it:

- **Cursor**: create it per the precedence, then call `move_agent_to_root` with the worktree's absolute path.
- **Claude Code**: `EnterWorktree(name=<branch>)` creates it and moves the session in one step. Take the worktree path from the tool's result.

## Step 4 — Make the blackboard ignorable

Add `.agent-flow/` to the shared exclude file (idempotent — see SKILL.md), then create the `.agent-flow/` directory in the worktree. (In github mode with the worktree deferred, just add the exclude — there is no worktree yet to hold the directory; `run` creates `.agent-flow/` when it makes the worktree.)

## Step 5 — Write the blackboard

**If `storage: github`** (the user opted into github mode, or a flow seeded from a `gh issue` and you offered it): do not write the three files. Instead run the preflight, create the dedicated tracking issue from `templates/ISSUE.md`, and drop the `.agent-flow/issue` pointer — the full procedure is in `references/github-mode.md` ("start (github mode)"). The same design content (README essence + PLAN + the phase/task checklist) goes into the issue body; the rest of this step describes the **local** mode.

Read the three files in this skill's `templates/` directory as the structure, and write filled-in versions into `<worktree>/.agent-flow/`:

- **README.md** — overview, prerequisites, and the *necessary* relations only (ticket link, related PRs, design docs). Not the full ticket.
- **PLAN.md** — the design decisions, the architecture, and an explicit "control flow" section stating the gates **and** the engine (Step 2) and why — for a `goal`/`ralph` engine, write the exact completion condition / re-feed prompt + phrase + cap there, since that *is* what `run` will issue.
- **TASKS.md** — the checklist that reflects the design, using the schema in SKILL.md:
  - Break the work into phases that match the chosen execution shape. A one-pass flow may be a single gateless phase; a flow needing review has `gate: review` / `gate: approve` at the right boundaries.
  - Give each task a `@role`, a `goal:`, and a `done:`. Not every task is the canonical design → implement → test → PR → review → fix sequence — let the design dictate the tasks. As a granularity guideline, aim for one task per independently-verifiable `done:` criterion — enough to track progress, not so fine it becomes noise. **Keep `@implement` coarse**: its app→test→lint→`/simplify` inner loop is the role's contract (run.md), so one `@implement` per unit is right — don't explode it into per-step rows. (Even under a `goal`/`ralph` engine, keep the task list: it is the across-iteration progress ledger the loop ticks.)
  - **Post-PR review is on by default.** Add a `gate: none` phase with one `@pr-review` task after the `@pr` phase, then a `gate: none` 修正 phase for the `@fix` tasks it appends; out-of-scope findings go to follow-up issues, not TASKS.md. Drop this phase only for a trivial change or when the user declines PR comments.
  - **Mode A**: the design is already approved, so the first phase can be 実装 — don't synthesize a 詳細設計 phase or its gate unless the user wants the transcription itself reviewed.
  - Fill the header: `flow`, `branch`, empty `pr`, `phase: 1`, and `engine:` from Step 2.

## Step 6 — Confirm and hand off

Show the user a compact summary of TASKS.md (phases, gates, engine, task count) — for a Mode B flow this is where the design gets the user's agreement before any task runs. Then:

- If the user explicitly asked for unattended / one-shot completion (e.g. "一気に進めて") **and** the flow is gateless, continue straight into `run` (see `run.md`).
- Otherwise hand off: tell them to invoke `agent-flow run` (e.g. `/agent-flow run` — the blackboard persists, so resuming in a fresh session is fine).

# agent-flow: github mode (`storage: github`)

The blackboard's medium swaps from on-disk files to a single GitHub **tracking issue**; everything else (phases, gates, engine, roles, the run loop) is unchanged. This file is the medium-specific contract — read it before any github-mode `start` / `run` / `done`. The generic per-phase logic still lives in `start.md` / `run.md` / `done.md`; only the read/write primitives and the lifecycle differ.

## When to use it

`local` is the default. Use github mode only when the user opts in — "githubモードで" / "issueで管理して" / "issue で進捗を追いたい" — or accept the cue: a flow **seeded from a `gh issue`** is a natural moment to *offer* github mode (don't switch silently). The payoff is team visibility, cross-machine resumability, and a durable issue record; the cost is network + auth + the constraints below.

## Preflight (before creating anything)

All must hold, or stop and tell the user (fall back to local mode is usually the right suggestion):

1. **Auth** — `gh auth status` succeeds.
2. **Target repo** — resolve where the issue lives: the repo the PR will open against (normally `origin`'s base). `gh repo view --json nameWithOwner,hasIssuesEnabled,defaultBranchRef`.
3. **Issues enabled** — `hasIssuesEnabled` is `true`. If issues are disabled (some forks / mirrors), github mode is impossible → suggest local.

Honor the 2-try environment-block rule: if auth/network fails twice, stop and report rather than thrashing.

## The tracking issue layout

**One issue** is the whole blackboard. Its **body** is the live control surface (edited in place); its **comments** are the append-only activity log.

### Body

Filled from `templates/ISSUE.md`. The header that was YAML frontmatter in TASKS.md becomes a **leading HTML-comment meta block** (issues have no frontmatter — a leading `---` just renders as a rule), and PLAN/README content sits above the phases:

```markdown
<!-- agent-flow:meta
flow: add-foo-endpoint
branch: feat/add-foo-endpoint
pr:
phase: 1
engine: subagent
storage: github
-->

## 概要
<README essence — overview, prerequisites, the necessary relations. Link the source ticket here.>

## 設計 (PLAN)
<design decisions, architecture, the control-flow section (gates + engine). Keep it concise; if it
 would push the body toward the 65,536-character cap, put the long form in a comment or a linked doc
 and leave a one-line link here.>

## Phase 1: 実装  <!-- gate: none -->
- [ ] ハンドラ実装 `@implement`
  - done: app + tests written, test + lint green, diff simplified
- [ ] PR 作成（draft） `@pr`
  - done: draft PR opened, meta pr: filled

## Phase 2: PR レビュー  <!-- gate: none -->
- [ ] PR レビュー `@pr-review`
  - done: findings posted inline; in-scope → `@fix`, out-of-scope → follow-up issue
```

**Faithful to TASKS.md, with exactly two transcription rules:**
- **Phases stay at `## Phase N: <name>  <!-- gate: ... -->`** — identical to local mode, so the same `^## Phase ` / `- [ ]` / `<!-- gate: -->` greps work once you've fetched the body. (`## 概要` / `## 設計` are siblings above the first phase; the `Phase` keyword keeps the phase grep unambiguous, and PLAN/README carry no `- [ ]`.)
- **Every `@role` is backticked** — `` `@implement` ``, `` `@pr` ``, etc. A bare `@role` renders as a GitHub @-mention (and can notify a real user who happens to own that handle). Code spans suppress mention *and* `#`-issue autolinking, so backticking is the one reliable fix.

### Comments = activity log

Post a comment only at **meaningful boundaries**, never per task tick (every comment notifies subscribers and counts against rate limits):

- flow created (with the plan summary), each **gate** checkpoint (what the phase produced; awaiting approval / the review result), `@pr` (the PR link), `@pr-review` (the findings summary), and `done` (final summary).

## Discovery pointer

**The worktree may not exist yet.** github mode does not create it at `start` (see "start (github mode)") unless the user explicitly asked — it is created at `run`, when code work begins. github mode writes no `.agent-flow/{PLAN,TASKS,README}.md`; once a worktree exists it drops a one-line pointer so a fresh `run`/`done` can rediscover the flow by the same `git worktree list` + `.agent-flow/` scan:

```
<worktree>/.agent-flow/issue     # contents: the issue URL (or owner/repo#number)
```

Until a worktree exists (and on any machine that only set up the issue), there is no local pointer — rediscover the flow from the tracking issue itself: the `agent-flow` label + `agent-flow:` title prefix (so apply that label at `start`), or the issue URL the user provides. The canonical state (phase, pr, engine, the checklist) lives in the **issue body**, not the pointer — the pointer is just the locator. `.agent-flow/` is excluded the same way as in local mode.

## Read / write primitives

The control logic is unchanged — only the I/O swaps. Prefer `gh` (consistent with the skill's `gh pr` usage); `mcp__github` is the fallback.

| Operation | `gh` | `mcp__github` |
|---|---|---|
| Read the control surface | `gh issue view <n> --json body --jq .body` → grep as if it were TASKS.md | `issue_read` |
| Write back (tick a box, bump `phase:`/`pr:`, append a task) | `gh issue edit <n> --body-file <tmp>` | `issue_write` |
| Log | `gh issue comment <n> --body ...` | `add_issue_comment` |

**Write discipline (the github-mode invariant):**
- **Single-writer** — only the `run` orchestrator edits the body. Subagents do work, commit, and report back; `run` ticks the box. Subagents may post comments but never edit the body.
- **Read-modify-write, re-fetched immediately before each edit** — issue bodies have no compare-and-swap, so a human toggling a checkbox in the UI would otherwise be clobbered. Fetch → change the one thing → write back. (GitHub keeps an edit history, so a stomp is recoverable, but don't rely on it.)
- **No concurrent body writes**, and don't comment per micro-step — both trip GitHub's secondary rate limits.

## start (github mode)

After the generic Steps 1–2 of `start.md` (design + execution shape), and Step 3 (slug + worktree *mechanism* — but **the worktree is not created at `start`** unless the user explicitly asked to work locally now; `run` creates it when code work begins):

1. **Preflight** (above). 
2. **Create the dedicated tracking issue** — title `agent-flow: <flow title>`, where `<flow title>` is a short **human-readable phrase** describing the work (e.g. `agent-flow: add --dry-run flag to foo CLI`), *not* the bare slug — the slug already lives in the meta block and the branch. Body from `templates/ISSUE.md` filled with the meta block, 概要, PLAN, and the phase/task checklist. Do **not** reuse the source ticket as the blackboard; if the flow was seeded from issue `#X`, write `関連: #X` in 概要 and (optionally) drop a comment on `#X` linking the new tracking issue.
   - `gh issue create --title "agent-flow: <title>" --body-file <tmp>` → capture the returned number/URL.
   - **The body need not embed its own number.** The number isn't known until create returns, but nothing in the body requires it: the template's `Closes #<this issue>` on the `@pr` line is resolved later by `@pr` **in the PR body**, not in the issue body. If you do want the number shown in the issue body (e.g. in 概要), that one post-create fill is a `start`-time orchestrator edit — the single-writer "only `run` edits the body" rule governs the run loop, not this initialization.
   - **Apply the discoverability label** — it is how `run`/`done` rediscover the flow while no worktree/pointer exists: `gh label create agent-flow --color ededed 2>/dev/null || true; gh issue edit <n> --add-label agent-flow`. Keep other metadata in the meta block, **not** in labels (labels must pre-exist and are flat strings).
3. **Drop the pointer — only if a worktree was created** (explicit request): write the issue URL (returned by create) to `<worktree>/.agent-flow/issue`. With the worktree deferred (the default), skip this — the label + title from step 2 are the locator until `run` makes the worktree.
4. **Confirm + hand off** as in `start.md` Step 6, but show the **issue URL** as the blackboard.

## run (github mode)

Identical loop to `run.md`, with the primitives swapped:

- **Load**: fetch the body (`gh issue view`), parse it exactly as you'd parse TASKS.md — `phase:` from the meta block is your position, `engine:` selects the driver.
- **Locate the flow + ensure a worktree before code work**: find the flow via the `.agent-flow/issue` pointer if a worktree already exists, else the `agent-flow`-labelled tracking issue (or the URL the user gives). `start` may have **deferred the worktree** — if none exists, create it from the meta `branch:` when the first **code-producing** task (`@implement` / `@fix` / `@refactor`) is due: per the resolved mechanism (`git worktree add .wt/<slug> <branch>`), enter it, then drop the `.agent-flow/issue` pointer. A `@design` phase only edits the issue body, so it needs no worktree — the worktree can wait until implementation.
- **Dispatch** subagents per `@role` exactly as in local mode; the dispatch prompt still carries the absolute worktree path and the task's `goal`/`done`, and says **work in the worktree, commit with `/incremental-commit`, and report back — do not touch the issue**. The orchestrator (you) then re-fetches the body, ticks `[x]`, and writes it back.
- **Gates**: `review` / `approve` / `none` behave the same; additionally **post a comment** recording the checkpoint (and, for `approve`, that you're waiting). For `approve`, the human still responds in-session — reactions/labels as async approval signals are a possible future enhancement, not v1.
- **`@pr`**: open the draft PR as usual and **include `Closes #<issue>` in the PR body** so the tracking issue auto-closes on merge; write the PR number into the meta block `pr:` and post the PR link as a comment.
- **`@pr-review` / `@address-review` / follow-ups**: as in `run.md`. Out-of-scope findings become *separate* issues linked from both the PR and the tracking issue — not unchecked boxes in the tracking-issue body (it closes when the PR merges).

### Engine interplay (`goal` / `ralph` in github mode)

The re-feed instruction must point at the issue, not a file, and must respect rate limits:

- `goal`: phrase the completion condition around demonstrable output — e.g. "`gh issue view <n>` shows no `- [ ]`, `npm test` exits 0, and `gh pr view` resolves with `Closes #<issue>` in the body" + the turn cap.
- `ralph`: the re-feed prompt becomes "fetch `gh issue view <n> --json body`, do the next `- [ ]` in `<worktree>`, commit, then `gh issue edit <n>` to tick it; if none remain (and the draft PR is open) output `<PHRASE>`." Because every iteration now does a `gh issue view` + `gh issue edit`, keep `--max-iterations` tight; for chatty loops prefer a **local scratch ledger synced to the issue at phase boundaries** over a write per tick.

## done (github mode)

Same guard as `done.md` (no remaining `- [ ]` — read from the **issue body**; branch pushed; PR exists; follow-ups externalized as separate issues), then:

1. Ensure the PR body contains `Closes #<issue>` (so the issue auto-closes on merge). Add it if missing.
2. Post a **final summary comment** on the tracking issue (PR link + what shipped).
3. Remove the worktree (`ExitWorktree(action="keep")` → `git worktree remove`). This deletes the `.agent-flow/issue` pointer with it — harmless, the issue is self-describing.
4. **Leave the issue open. Never delete it** (the API can't anyway — issues only close). It auto-closes when the user merges the PR; merging stays the user's manual step.

Because the issue persists, an `@address-review` round after `done` is easy to resume: re-attach a worktree on the PR branch (`git worktree add .wt/<slug> <branch>`), re-drop the `.agent-flow/issue` pointer, and run.

## GitHub-specific constraints (catalog)

| Constraint | Handling |
|---|---|
| Issues have **no YAML frontmatter** (`---` renders as a rule) | Header → leading `<!-- agent-flow:meta ... -->` HTML comment (preserved in raw markdown, invisible when rendered) |
| `@role` renders as an **@-mention** (can notify a real user) | Backtick every role: `` `@implement` `` (code spans also suppress `#`-autolinking) |
| Body capped at **65,536 characters** (counted in characters, not bytes — multibyte text gets the full count) | Keep PLAN concise in the body; spill an oversized design to a comment or a linked doc + a one-line link |
| Body has **no compare-and-swap**; UI toggles can clobber | Single-writer (`run` only) + re-fetch immediately before each edit |
| **Secondary rate limits** (bursty content creation, concurrent writes) | No per-tick comments; no concurrent body writes; batch where possible |
| Issues **cannot be deleted** via the normal API (only closed) | `done` leaves the issue open / lets the PR merge close it; never attempts deletion |
| **Labels must pre-exist** and are flat strings | Keep all metadata in the meta block; use at most one `agent-flow` label (create-if-missing) for discoverability |
| Comments/edits **notify subscribers**; activity is attributed to the `gh` token's owner | Comment only at boundaries; be aware the actor is the authenticated identity |

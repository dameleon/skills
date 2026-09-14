# agent-flow: done

Finish the flow and remove the disposable blackboard. The whole point of cleanup is that the durable record now lives in the PR — so verify that before destroying anything.

## Step 1 — Locate the flow

Find the target worktree (slug arg, or discover via `git worktree list` + `.agent-flow/`). Read the TASKS.md header for `branch` and `pr`.

**If `storage: github`** (the worktree carries `.agent-flow/issue`, not `TASKS.md`): the blackboard is the tracking issue, which is **durable, not disposable** — the guard reads the remaining `- [ ]` from the *issue body*, and cleanup removes only the worktree while leaving the issue open (it auto-closes when the PR merges). Follow `references/github-mode.md` ("done (github mode)") for the exact steps; never delete the issue.

## Step 2 — Verify it is safe to clean up (guard)

All of these must hold — if any fails, **stop and report; do not remove anything**:

- No remaining `- [ ]` in TASKS.md (or the user explicitly accepts finishing with open tasks).
- The branch is pushed and up to date with its remote (`git -C <worktree> status` shows nothing un-pushed).
- The working tree is clean (`git -C <worktree> status --porcelain` is empty) — uncommitted or untracked work would be destroyed with the worktree.
- A PR exists (`pr:` is set, or `gh pr view` on the branch resolves).
- Any out-of-scope follow-ups are externalized (follow-up issues / PR body), **not** left only in TASKS.md — the blackboard is about to be destroyed, so anything still living there is lost.

This guard is the only thing standing between "disposable blackboard" and "lost work." Un-pushed commits or a missing PR mean the history is *not* yet durable.

**If an external review round is still expected** (a human / Copilot reviewer will comment on the PR), the flow is not really done: either hold off on `done` and keep the worktree until those comments are resolved, or `done` now and — when the review arrives — re-attach a worktree on the PR branch (Claude Code: `EnterWorktree(name=<branch>)` — a git-wt-style hook checks out the existing branch, so verify with `git branch --show-current`; Cursor: `git worktree add .wt/<slug> <branch>` or the project's tool) to run an `@address-review` round, then clean up again.

## Step 3 — Remove the worktree

Removing the worktree also deletes the blackboard — that is by design.

- **Claude Code**: if the session is not inside the worktree (Step 1 may have found it from the main repo), `EnterWorktree(path=<worktree>)` first. Then `ExitWorktree(action="remove", discard_changes: true)`. Step 2's guard already proved the worktree pushed and clean, which is what the flag asserts; the call runs the environment's `WorktreeRemove` hook (e.g. git-wt's delete hook), which `ExitWorktree(action="keep")` + raw `git worktree remove` would skip. If the tool still refuses, report the path and let the user rescue it.
- **Cursor**: `move_agent_to_root` back to the main repo path, then remove it with the project's tool (`git wt -d <branch>` in git-wt repos) or `git -C <main-repo> worktree remove <worktree>`. Do **not** `--force`; if git refuses (unexpected uncommitted state), report the path and let the user rescue it manually.

The `.agent-flow/` entry in the exclude file is harmless and reusable across future flows — leave it.

## Step 4 — Report

Summarize: the PR link, what was built, and confirm the worktree was removed. The blackboard is gone by design; the PR is the record.

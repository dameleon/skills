# agent-flow: Build and Verify

Build delegates the units one at a time and checks each before the next. Verify has an agent that did not write the code prove the whole change on the real artifact.

## The worktree

Create it at the first write the flow needs: during Design for a bug fix or a refactoring, at the first unit otherwise.

**Create it explicitly, then enter it by path.** `EnterWorktree(name=...)` always makes a new branch with a name of its own choosing, so it cannot give the flow a chosen branch, a chosen base, or an existing branch.

```bash
git fetch origin
git worktree add --no-track .claude/worktrees/<slug> -b <type>/<slug> origin/<default-branch>
```

Then `EnterWorktree(path=<absolute path of .claude/worktrees/<slug>>)`.

- `<type>` is `feat`, `fix`, `refactor`, or `chore`. For another base, replace `origin/<default-branch>`. `--no-track` keeps the new branch from tracking the base; the first `git push -u origin <branch>` sets its real upstream.
- **To re-attach an existing branch** (a resumed flow whose worktree is gone, or review that arrived after Close):
  ```bash
  git worktree prune
  git fetch origin <branch>
  git worktree add .claude/worktrees/<slug> <branch>
  git -C .claude/worktrees/<slug> merge --ff-only origin/<branch>
  ```
  then enter by path. `prune` clears a registration left by a deleted directory, and the fast-forward brings a stale local branch up to the remote.
- **If the project or the user has a worktree rule** (a `WorktreeCreate` hook, a wrapper such as `git wt`, a path convention in CLAUDE.md), follow that instead. A project that wraps worktree creation to copy `.env` or similar leaves a plainly created worktree unbootable.
- After entering, run `git branch --show-current` and write that value to the meta block's `branch:`. Whatever the worktree really has is the truth.
- Keep both `.agent-flow/` and `.claude/worktrees/` out of commits through the shared exclude file, and write the issue URL to `<worktree>/.agent-flow/issue` (`references/issue.md`).
- Record the absolute path. Every brief needs it.

## Build

Set `stage: build`. Then repeat until `実装` has no unticked sub-item, or a `⏸ 承認` is next.

1. **Re-fetch the issue body and take the next unticked unit.** Respect the order Design gave it.
2. **On a resumed session only, check whether that unit was already finished.** A crash after a commit but before the tick leaves a finished unit unticked. Every tick records the commit it ended on, so compare: the unit is done only when the tree is clean (`git -C <worktree> status --porcelain` is empty), `HEAD` is ahead of the SHA on the last ticked unit, those new commits are this unit's work, and its `verify:` passes. Then tick it. A `verify:` that passes with no new commit proves nothing, because a regression guard such as "the pin stays green" is true before the unit starts. If the tree is dirty, a delegate died mid-unit: read the diff, and either finish and commit it or discard it. Never tick uncommitted work.
3. **Run it.**
   - **A code unit is delegated** per `references/pstack.md` ("Delegate briefs"). Take scope and model from the playbook's own delegate step; `generic` has none, so use pstack's `feature, refactoring` line or default. The brief adds:
     - the unit's scope: file paths, the named data shape, what must not change
     - its `verify:` line as the success criterion
     - "work inside `<worktree>`, commit with `/incremental-commit`, do not touch the tracking issue, report what you ran and what it printed"

     When the unit's implementation admits several valid shapes, the feature playbook requires `arena` in place of a single delegate. Follow it, with seats per `references/pstack.md`.
   - **A unit that is a judgment or an operation is run by this session**: the refactoring "is it worth keeping" check, or the step behind a `⏸ 承認`.
4. **Check the unit yourself.** You own the delegate's work. Read the diff and run the `verify:` line; a delegate's "passed" is a claim. If a check passes too easily, suspect the check before the code.
5. **Tick it, or send it back.** On a pass, confirm the work is committed (commit it if the delegate did not), push the branch, and tick the box with the commit appended: `- [x] a. handler for POST /foo (3a9f1c2)`. On a failure, give the fix round to a **fresh** delegate with the original brief, what failed, and the prior report. After repeated failures on one premise, write the premise down and test it directly before another fix.
6. **Record what a reviewer would need.** A fork chosen, a revert, a discovery that changes 設計. Collect these for the "Build finished" comment. A discovery that changes the design is corrected in 設計 now, with its own comment.

**Push after every commit that ends a step**: each ticked unit, and the reproduction or pin committed during Design (`git push -u origin <branch>` the first time). A pushed branch is reversible and opens no PR, and it is what lets another machine or session pick the flow up.

**Commit in the order that proves the work, as you go**: the reproduction before the fix, the pin and the subtraction before the reshape. Order built during Build does not have to be repaired later.

**Order and parallelism.** Units run serially in the flow's worktree by default, each ending green before the next starts. Units the throughput checkpoint marked independent may run concurrently only when each delegate gets its own checkout (`isolation: "worktree"`, naming the commit to start from). Integrate their commits into the flow's branch yourself, one at a time, running each unit's `verify:` after it lands. Two delegates never write the same worktree at once.

**Mid-run discoveries.** A related bug, a flaky check, or broken tooling that blocks the goal is yours to fix; add a unit. Anything the PR should not carry becomes a separate issue, linked later from the PR.

**If a refactoring's last check says the change is not worth keeping**, revert it, push, and stop: post a Close comment saying nothing shipped and why, set `stage: closed`, and tell the user. There is no PR, so whether to close the issue is theirs.

## Stops

When the next sub-item is `⏸ 承認: ...`:

1. Post the comment for that boundary: what is about to happen, what was verified so far, what the user needs to decide.
2. Ask the user and wait. Tick the item only on their answer.
3. Run the unit that follows it in this session, and put the command and its output in the decision log.

A session override ("止まらずに") does not skip this.

## Before Verify

When the units are done, finish everything that can still change the code or the history, so the SHA that gets verified is the SHA the PR carries. `実装` stays unticked until this section is done.

1. **Contested design → `interrogate`.** If two shapes were close, a reviewer or the user pushed back, or Build exposed doubt about the approach, run `interrogate` on the branch diff. Only findings a run proves survive. Each becomes a unit; go back to the loop.
2. **`/simplify`**, unless the project has its own rule. Default: run it for new logic, refactors, or multi-file changes; skip it for docs, config, generated files, or a few local lines, and note the skip for the PR body. The worktree is clean, so name the range: the changes in `git diff origin/<base>...HEAD`. If it changes code, rerun the affected units' `verify:` lines and commit.
3. **Tidy the history only if it needs it.** If the commits are not small, ordered, and each landing on its own, rewrite them now and push with `git push --force-with-lease`. The flow's own branch before its PR exists is not a shared branch, so this needs no `⏸ 承認`. After the PR is open, do not rewrite; add commits.

Then tick `実装` and post the "Build finished" comment.

## Verify

Set `stage: verify`. This is the `独立検証` item.

1. **Name the head.** `git -C <worktree> rev-parse HEAD`. The verdict covers this SHA.
2. **Spawn a verifier that wrote none of the code.** `subagent_type: "general-purpose"`, with `model` and `effort` passed explicitly from pstack's `swarm workers` line or default. Write the brief the way pstack's `swarm` skill writes a worker brief, so that it stands alone:
   - the goal and the done predicate from 設計
   - the exact SHA and the worktree path
   - how to exercise the change the way a user would, on the surface it ships on: run the CLI, call the endpoint, drive the UI. Tests are part of the evidence, not all of it. For a bug fix, rerun the reproduction. For a refactoring, run the pin.
   - edit nothing; report one of the three verdicts below, with the commands run and their output

   The verdict words are agent-flow's, not swarm's `PASS` / `ISSUES` / `BLOCKED`. State them in the brief.
3. **Read the verdict.**

| Verdict | Meaning | Next |
|---|---|---|
| `VERIFIED` | The done predicate was observed on the real artifact at this SHA | Tick `独立検証`, go to Ship |
| `NOT VERIFIED` | A run shows the predicate does not hold | Add a unit per proven failure, untick `実装`, set `stage: build`, return to Build |
| `INCONCLUSIVE` | The verifier could not reach the surface, or the evidence is the wrong kind | Not a pass. Fix the way of observing, then verify again |

4. **Audit the receipts.** Check that the commands in the report exist and say what the report claims. Rerun any that the verdict rests on.
5. **Post the "Verify verdict" comment**: verdict, SHA, verifier model, evidence pointers.

**How long a verdict lasts.** It covers the code, not the commit. A later head whose content is identical (`git diff <verified-sha> HEAD` prints nothing) keeps the verdict; cite both SHAs. A change in behavior gets one fresh verifier at the new head. A change only to wording, comments, or formatting gets none.

**Driving the real surface.** pstack's playbooks name `control-ui` and `control-cli`, which ship in a plugin that may not be installed. Use what the project has: a project-local `verify-*` skill, a browser automation skill, or the CLI itself. If nothing can drive the surface, say so in the verdict comment and name what was checked instead. Do not report `VERIFIED` on tests alone when the change has user-visible behavior.

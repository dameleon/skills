# agent-flow: Build and Verify

Build delegates the units one at a time and checks each before the next. Verify has an agent that did not write the code prove the whole change on the real artifact.

## The worktree

Create it at the first write the flow needs: the reproduction for a bug fix, the pin for a refactoring, the first unit otherwise.

- `EnterWorktree(name=<branch>)`. The harness creates the worktree through the environment's `WorktreeCreate` hook when one is configured, so do not run `git worktree add` or `git wt` yourself for the flow's worktree. To start from a base other than the default branch, create the branch first (`git branch --no-track <branch> <base>`), then enter. Check `git branch --show-current` afterward.
- Record the path the tool reports. Every brief needs it.
- Add `.agent-flow/` to the shared exclude file and write the issue URL to `<worktree>/.agent-flow/issue` (`references/issue.md`).
- On resume, re-enter with `EnterWorktree(path=<worktree>)` before any write.

## Build

Set `stage: build`. Then repeat until the playbook's delegate step has no unticked unit, or a `⏸ 承認` item is next.

1. **Re-fetch the issue body and take the next unticked unit.** Respect the order Design gave it.
2. **Check whether it is already done.** A crash after a commit but before the tick leaves a finished unit unticked. Run its `verify:` against the worktree. If it holds, tick it and move on. Re-dispatching finished work only returns "nothing to do."
3. **Delegate it** per `references/pstack.md` ("Delegate briefs"), following the playbook's own delegate step for scope and model. The brief adds:
   - the unit's scope: file paths, the named data shape, what must not change
   - its `verify:` line as the success criterion
   - "work inside `<worktree>`, commit with `/incremental-commit`, do not touch the tracking issue, report what you ran and what it printed"

   When the unit's implementation admits several valid shapes, the feature playbook requires `arena` in place of a single delegate. Follow it, with non-Claude seats per `references/pstack.md`.
4. **Check the unit yourself.** You own the delegate's work. Read the diff and run the `verify:` line; a delegate's "passed" is a claim. If a check passes too easily, suspect the check before the code.
5. **Tick it, or send it back.** On a pass, confirm the work is committed (commit it if the delegate did not) and tick the box. On a failure, give the fix round to a **fresh** delegate with the original brief, what failed, and the prior report. After repeated failures on one premise, write the premise down and test it directly before another fix.
6. **Record what a reviewer would need.** A fork chosen, a revert, a discovery that changes 設計. Collect these for the "Build finished" comment. A discovery that changes the design is corrected in 設計 now, with its own comment.

**Order and parallelism.** Units run serially in the flow's worktree by default, each ending green before the next starts. Units the throughput checkpoint marked independent may run concurrently only when each delegate gets its own checkout (`isolation: "worktree"`, naming the commit to start from). Integrate their commits into the flow's branch yourself, one at a time, running each unit's `verify:` after it lands. Two delegates never write the same worktree at once.

**Mid-run discoveries.** A related bug, a flaky check, or broken tooling that blocks the goal is yours to fix; add a unit. Anything the PR should not carry becomes a separate issue, linked later from the PR.

When the last unit is ticked, post the "Build finished" comment.

## Stops

When the next item is `⏸ 承認: ...`:

1. Post the comment for that boundary: what is about to happen, what was verified so far, what the user needs to decide.
2. Ask the user and wait. Tick the item only on their answer.

A session override ("止まらずに") does not skip this.

## Contested designs

If the design is contested — two shapes were close, a reviewer or the user pushed back, or Build exposed doubt about the approach — run `interrogate` on the branch diff before Verify. Only findings a run proves survive. Each surviving finding becomes a unit with its own `verify:`, and Build continues.

## Verify

Set `stage: verify`. This is the `独立検証` item.

1. **Name the head.** `git -C <worktree> rev-parse HEAD`. The verdict covers this SHA and nothing later.
2. **Spawn a verifier that wrote none of the code.** Use the brief and report format of pstack's `swarm` skill, on the `swarm workers` model. The brief stands alone:
   - the goal and the done predicate from 設計
   - the exact SHA and the worktree path
   - how to exercise the change the way a user would, on the surface it ships on: run the CLI, call the endpoint, drive the UI. Tests are part of the evidence, not all of it.
   - report the verdict with the commands run and their output; edit nothing
3. **Read the verdict.**

| Verdict | Meaning | Next |
|---|---|---|
| `VERIFIED` | The done predicate was observed on the real artifact at this SHA | Tick `独立検証`, go to Ship |
| `NOT VERIFIED` | A run shows the predicate does not hold | Add a unit per proven failure, return to Build |
| `INCONCLUSIVE` | The verifier could not reach the surface, or the evidence is the wrong kind | Not a pass. Fix the way of observing, then verify again |

4. **Audit the receipts.** Check that the commands in the report exist and say what the report claims. Rerun any that the verdict rests on.
5. **Post the "Verify verdict" comment**: verdict, SHA, verifier model, evidence pointers.

A later change to the patch needs a fresh check at the new head. A fix that changes behavior gets one verifier. A change to wording, comments, or formatting gets none.

If the project has no way to drive the real surface, say so in the verdict comment and name what was checked instead. Do not report `VERIFIED` on tests alone when the change has user-visible behavior.

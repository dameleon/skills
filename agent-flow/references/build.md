# agent-flow: Build and Verify

Build delegates the units one at a time and checks each before the next. Verify has an agent that did not write the code prove the whole change on the real artifact.

## The worktree

Create it at the first write the flow needs: during Design for a bug fix or a refactoring, at the first unit otherwise.

In this section `<main>` is the absolute path of the main checkout (the first entry of `git worktree list`) and `<worktree>` is the absolute path of the flow's worktree. Keep both; every brief needs the second, and commands written with them work from any directory.

### Before creating or re-attaching it

Still in the main checkout, every time a worktree is about to be created or re-attached on this machine:

- **Look for a worktree rule** of the project or the user: a `WorktreeCreate` hook in settings, a wrapper such as `git wt`, a path convention in CLAUDE.md. If there is one, read "With a worktree rule" below before creating.
- **Add the exclude lines** (`references/issue.md`, "Locating a flow"). The exclude file lives in the main checkout's git directory, which a session that has entered a worktree may not be allowed to write, and it is per clone, so another machine starts without them.

### Create, Record, Push, Enter

Without a hook, `EnterWorktree(name=...)` makes a new branch with a name of its own choosing, so it cannot give the flow a chosen branch, a chosen base, or an existing branch. **Create** the worktree explicitly instead. Run these one at a time:

```bash
git fetch origin
git worktree add --no-track <main>/.claude/worktrees/<slug> -b <type>/<slug> origin/<base>
```

`<type>` is `feat`, `fix`, `refactor`, or `chore`, and `<base>` is the meta block's `base:`. `--no-track` keeps the new branch from tracking the base. Then, in this order:

- **Record.** Write `git -C <worktree> branch --show-current` to the meta block's `branch:` (whatever the worktree really has is the truth), and write the issue URL to `<worktree>/.agent-flow/issue`. Doing this before Push means a flow that stops there can still be found.
- **Push** the empty branch: `git -C <worktree> push -u origin <type>/<slug>`. This is the only real test that this machine can push. `gh` and `git` authenticate separately and can be different accounts, so a passing preflight does not prove it. If the push is refused, stop before any work is done. Report the error and where the push went (`git -C <worktree> remote get-url --push origin`), and leave the fix to the user; do not switch accounts or rewrite the remote yourself. The worktree and the local branch stay. When the flow resumes, run Push again; do not create them a second time.
- **Enter**: `EnterWorktree(path=<worktree>)`, and stay for the rest of the flow. Invoking `/agent-flow` is the user's instruction to work in a worktree, which is the condition that tool sets for its use. From here the current directory is the worktree, so plain `git`, the `verify:` commands, and every skill that reads the current directory (`/incremental-commit`, `/simplify`, `/pr-review-toolkit:review-pr`, pstack's `interrogate` and `arena`, `closing`) act on the flow's branch.

**A resumed session starts in the main checkout.** Find the worktree from the meta block's `branch:` and `git worktree list --porcelain`. If `git -C <worktree> rev-parse --abbrev-ref @{u}` fails, the first push never landed: do Push first. Then Enter, before anything else. If the worktree is gone, re-attach it (below).

### Inside an entered worktree

The harness is stricter there. Known so far:

- It refuses git commands that carry `-c` options, such as a push that names a credential helper. Do not add one. If a plain `git push` is refused, that is an access problem: report it as in Push.
- It refuses compound commands that mix `git` or `gh` with other steps. Run one command per call. If it also refuses the `git commit -m "$(cat <<EOF ...)"` form that `/incremental-commit` uses, write the message to a scratch file and use `git commit -F <file>`.
- Temporary files (issue bodies, comments, PR bodies, review payloads) go in the session's scratch directory, never in the worktree, where they would show up in `git status` and could be committed.
- The tool's own rules say not to leave with `ExitWorktree` unless the user asks. The session ends the flow inside the worktree.

### Re-attaching an existing branch

For a resumed flow whose worktree is gone, or review that arrived after Close. Do "Before creating or re-attaching it" first. Then run these one at a time; written with `<main>`, they work from any directory. Use these plain commands even when there is a worktree rule: a rule's hook may cut a fresh branch from the base instead of checking out the existing one. If the rule also prepares the worktree (copies `.env`, installs dependencies), tell the user that step was skipped. Then rewrite the pointer and Enter. If the fetch fails because the remote has no such branch, the first push never landed: go back to Create, with the same branch name.

```bash
git -C <main> worktree prune
git -C <main> fetch origin <branch>
git -C <main> worktree add <main>/.claude/worktrees/<slug> <branch>
git -C <main>/.claude/worktrees/<slug> merge --ff-only origin/<branch>
```

`prune` clears a registration left by a deleted directory, and the fast-forward brings a stale local branch up to the remote.

### With a worktree rule

This applies to creating a new worktree only. A project that wraps worktree creation, for example to copy `.env`, leaves a plainly created worktree unbootable, so its rule comes first. Read the hook or wrapper to learn how it names the branch and where it puts the worktree. With a `WorktreeCreate` hook, the base is not the hook's choice: Claude Code passes it a starting ref. Do not trust what that ref will be. The tool describes it as the remote default branch unless `worktree.baseRef` is `head`, but a run with the setting unset started the branch at the main checkout's current `HEAD`, which was another feature branch.

Follow these in order.

1. **Settle the branch name.** If the rule gives the branch a name of its own, that name is the flow's branch: use it wherever this list writes `<type>/<slug>`.
2. **Make sure that name is free.** In the main checkout, after `git fetch origin`, both `git rev-parse --verify --quiet refs/heads/<type>/<slug>` and `git ls-remote --heads origin <type>/<slug>` must print nothing. A hook handed an existing branch checks it out instead of creating one, and step 4 would then throw its commits away. If either prints something, create nothing: tell the user which of the two exists and at what commit, and wait for their instruction. With a new slug from them, start again from step 1.
3. **Create through the rule.** With a `WorktreeCreate` hook that is `EnterWorktree(name="<type>/<slug>")`, which creates and enters in one step.
4. **Check the starting point before anything else.** `git rev-parse HEAD origin/<base>` must print the same SHA twice. If it does not, move the branch: `git reset --hard origin/<base>`. This is safe only because step 2 found the name free, so the branch is new, holds no work, and is not pushed. Skipping it puts the other branch's commits into the flow's PR.
5. **Record and Push** then run from inside, with plain `git`; if the push is refused, the session stops where it is, inside.

Wherever this skill writes `<main>/.claude/worktrees/<slug>`, use the path the rule produces. If that path is inside the repo, add its parent directory to the exclude file in place of `.claude/worktrees/`.

## Build

Set `stage: build`. Then repeat until `実装` has no unticked sub-item, or a `⏸ 承認` is next.

1. **Re-fetch the issue body and take the next unticked unit.** Respect the order Design gave it.
2. **On a resumed session only, check whether that unit was already finished.** A crash after a commit but before the tick leaves a finished unit unticked. Every tick records the commit it ended on, so compare: the unit is done only when the tree is clean (`git status --porcelain` is empty), `HEAD` is ahead of the SHA on the last ticked unit, those new commits are this unit's work, and its `verify:` passes. Then tick it. A `verify:` that passes with no new commit proves nothing, because a regression guard such as "the pin stays green" is true before the unit starts. If the tree is dirty, a delegate died mid-unit: read the diff, and either finish and commit it or discard it. Never tick uncommitted work.
3. **Run it.**
   - **A code unit is delegated** per `references/pstack.md` ("Delegate briefs"). Take scope and model from the playbook's own delegate step; `generic` has none, so use pstack's `feature, refactoring` line or default. The brief adds:
     - the unit's scope: file paths, the named data shape, what must not change
     - its `verify:` line as the success criterion
     - "work inside `<worktree>`. Check `pwd` first; if you were not started there, use absolute paths for files and `git -C <worktree>` for git, and run tests from that directory"
     - the four prohibitions from `references/pstack.md` ("Delegate briefs"), in its words: commit, do not push, do not open a PR, do not touch the tracking issue
     - "commit in small logical commits, and report what you ran and what it printed"

     When the unit's implementation admits several valid shapes, the feature playbook requires `arena` in place of a single delegate. Follow it, with seats per `references/pstack.md`.
   - **A unit that is a judgment or an operation is run by this session**: the refactoring "is it worth keeping" check, or the step behind a `⏸ 承認`.
4. **Check the unit yourself.** You own the delegate's work. Read the diff and run the `verify:` line; a delegate's "passed" is a claim. If a check passes too easily, suspect the check before the code.
5. **Tick it, or send it back.** On a pass, confirm the work is committed (`git status --porcelain` prints nothing; commit it with `/incremental-commit` if the delegate did not), push with `git push`, confirm the remote has it (`git fetch origin <branch>`, then `git rev-parse HEAD origin/<branch>` prints the same SHA twice), and tick the box with the commit appended: `- [x] a. handler for POST /foo (3a9f1c2)`. On a failure, give the fix round to a **fresh** delegate with the original brief, what failed, and the prior report. After repeated failures on one premise, write the premise down and test it directly before another fix.
6. **Record what a reviewer would need.** A fork chosen, a revert, a discovery that changes 設計. Collect these for the "Build finished" comment. A discovery that changes the design is corrected in 設計 now, with its own comment.

**Push after every commit that ends a step**: each ticked unit, and the reproduction or pin committed during Design (`git push`; the upstream was set when the worktree was created). A pushed branch is reversible and opens no PR, and it is what lets another machine or session pick the flow up.

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
2. **`/simplify`**, unless the project has its own rule. Default: run it for new logic, refactors, or multi-file changes; skip it for docs, config, generated files, or a few local lines, and note the skip for the PR body. The skill spawns four review agents. For new code of a couple of hundred lines or fewer, read it yourself against the skill's four angles (reuse, simplification, efficiency, altitude) instead, and say so in the "Build finished" comment. The worktree is clean, so name the range: the changes in `git diff origin/<base>...HEAD`. If it changes code, rerun the affected units' `verify:` lines, commit, and push.
3. **Tidy the history only if it needs it.** If the commits are not small, ordered, and each landing on its own, rewrite them now. An interactive rebase is not available to an agent, so rebuild instead: note the old head (`git rev-parse HEAD`), find the fork point with `git merge-base HEAD origin/<base>`, run `git reset <fork point>` (the default mixed reset, which leaves every change unstaged), and commit again in order with `/incremental-commit`. The final tree does not change; confirm it with `git diff <old head> HEAD` printing nothing. This can only split by file, so leave the history alone when the fix would need to split one file's changes. Push with `git push --force-with-lease`. The SHAs on the ticked units are no longer on the branch, so replace each with the new commit that holds the last of that unit's files. The flow's own branch before its PR exists is not a shared branch, so this needs no `⏸ 承認`. After the PR is open, do not rewrite; add commits.

Then tick `実装` and post the "Build finished" comment.

## Verify

Set `stage: verify`. This is the `独立検証` item.

1. **Name the head, and check the tree yourself.** `git rev-parse HEAD` gives the SHA the verdict covers, and `git status --porcelain` must print nothing. Do both in the session and write the results into the brief as facts. Do not make them a precondition the verifier must confirm before starting: a verifier whose git read is refused by a hook or a permission check then stops having observed nothing.
2. **Spawn a verifier that wrote none of the code.** `subagent_type: "general-purpose"`, with `model` and `effort` passed explicitly from pstack's `swarm workers` line or default. Write the brief the way pstack's `swarm` skill writes a worker brief, so that it stands alone:
   - the goal and the done predicate from 設計
   - the exact SHA and the absolute worktree path, with the same "check `pwd` first" line a delegate gets
   - how to exercise the change the way a user would, on the surface it ships on: run the CLI, call the endpoint, drive the UI. Tests are part of the evidence, not all of it. For a bug fix, rerun the reproduction. For a refactoring, run the pin.
   - edit nothing; report one of the three verdicts below, with the commands run and their output
   - a step that cannot be run is reported as not checked, and the rest still runs. If a step that observes the done predicate could not run, the verdict is `INCONCLUSIVE`

   The verdict words are agent-flow's, not swarm's `PASS` / `ISSUES` / `BLOCKED`. State them in the brief.
3. **Read the verdict.**

| Verdict | Meaning | Next |
|---|---|---|
| `VERIFIED` | The done predicate was observed on the real artifact at this SHA | Tick `独立検証`, go to Ship |
| `NOT VERIFIED` | A run shows the predicate does not hold | Add a unit per proven failure, untick `実装`, set `stage: build`, return to Build |
| `INCONCLUSIVE` | The verifier could not reach the surface, or the evidence is the wrong kind | Not a pass. Fix the way of observing, then verify again |

4. **Audit the receipts.** Check that the commands in the report exist and say what the report claims. Rerun any that the verdict rests on. Run the bookkeeping steps the verifier reported as not checked (a git read, the clean-tree check after its runs). That fills in bookkeeping only: your own run never stands in for the verifier observing the done predicate.
5. **Post the "Verify verdict" comment**: verdict, SHA, verifier model, evidence pointers.

**How long a verdict lasts.** It covers the code, not the commit. A later head whose content is identical (`git diff <verified-sha> HEAD` prints nothing) keeps the verdict; cite both SHAs. A change in behavior gets one fresh verifier at the new head. A change only to wording, comments, or formatting gets none. A change only to tests (`git diff --name-only <verified-sha> HEAD` lists test files and nothing else) gets none either: run the changed tests yourself, and check that they fail when the behavior is broken. Break the behavior in a copy outside the worktree, or confirm `git status --porcelain` is empty once you have put it back.

**Driving the real surface.** pstack's playbooks name `control-ui` and `control-cli`, which ship in a plugin that may not be installed. Use what the project has: a project-local `verify-*` skill, a browser automation skill, or the CLI itself. If nothing can drive the surface, say so in the verdict comment and name what was checked instead. Do not report `VERIFIED` on tests alone when the change has user-visible behavior.

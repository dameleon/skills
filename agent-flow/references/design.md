# agent-flow: Frame and Design

Both stages are done by the agent-flow session itself. The design is never handed to a subagent. Subagents may gather: tracing a large subsystem or parsing a long ticket can be delegated, with the summary kept in the session.

Frame is read-only. Design is read-only too for `feature` and `generic`, and prototypes go in a scratch directory outside the repo. For `bug-fix` and `refactoring`, Design has to write (the reproduction, the pin), so it creates the worktree and works there from that point.

## Frame

1. **Resolve pstack and read the adapter and `poteto-mode/SKILL.md`** (`references/pstack.md`). Run the issue preflight (`references/issue.md`).
2. **Restate the goal and the smallest change that meets it.** This is poteto-mode's first non-negotiable. The restatement becomes `## 目的`.
3. **Take in what already exists.** A plan approved in plan mode, a design worked out earlier in the conversation, or a ticket is **input**. Do not redo it and do not treat it as finished: Design checks it against what the playbook requires and fills only the gaps. Pull a ticket with `gh issue view` and distill it.
4. **Pick the playbook** (the table in SKILL.md). For `feature`, `bug-fix`, and `refactoring`, read the playbook file in full.
5. **Derive the slug.** A short kebab-case name from the subject of the work. If an open tracking issue or a worktree already uses it, stop and ask whether to resume or rename. Never reuse one silently.
6. **Create the tracking issue** from `templates/ISSUE.md`: the meta block with `stage: design` and an empty `branch:`, 目的, and 手順 with the `設計` sub-items for the chosen playbook (the table below). Leave 設計 as the single line `設計中`. Apply the `agent-flow` label.

Then go straight into Design. Do not hand off and do not ask to proceed.

## Where each playbook step goes

The six top-level items of 手順 are fixed (`references/issue.md`). A playbook step lands in one of them.

| Playbook | `設計` sub-items (done in Design) | `実装` units (done in Build) | Absorbed elsewhere |
|---|---|---|---|
| `feature` | 1 trace, 2 `architect`, 3 throughput checkpoint | 4 delegate code-writing | 5 verify → `独立検証`; 6 rebase → `PR 作成`; 7 `interrogate` → Build, "Contested designs"; 8 → `PR 作成` |
| `bug-fix` | 1 reproduce, 2 find the cause, 3 plan the fix | 3's delegated implementation | 4 verify → `独立検証`, which reruns the reproduction; 5 stage the commits → `PR 作成`; 6 → `PR 作成` |
| `refactoring` | 1 pin the contract, 2 name the missing structure, 3 name the target shape | 4 subtract, 5 move in small steps, 7 confirm the change is worth keeping | 6 prove behavior unchanged → `独立検証`, against the pin; 8 → `PR 作成` |
| `generic` | one item: 変更内容と確認方法を決める | the change itself | — |
| `figure-it-out` | Phase A frame, Phase B design the workflow | the phase list Phase B designed, run under Phase C | Phase D log → issue comments; Phase E → `独立検証` |

Step numbers are pstack's, as of the version this was written against. If a playbook has changed, map each of its steps by the same rule: before code is delegated → `設計`; code → `実装`; verification, commit tidying, and PR → the fixed items.

## Design

Run the `設計` sub-items, ticking each in the issue as it completes.

### feature

- `architect` sketches **two** shapes and picks one. Record both. When the design is large or contested, `architect` routes to `arena`; seats follow `references/pstack.md`.
- The throughput checkpoint is four items, each answered or marked `n/a: <reason>`: blocking first steps, independent workstreams, shared mutable state, smallest safe decomposition.

### bug-fix

- **Create the worktree first** (`references/build.md`, "The worktree"). Reproduction and instrumentation write files.
- **Reproduce it yourself**, on the real surface. pstack keeps this with the owner; it is not a unit and is not delegated. Commit the reproduction (a failing test where there is a cheap test path) on its own, before any fix, and tick the sub-item.
- **Find the cause.** Narrow to one mechanism and confirm it with a run. Design is not complete until then; a fix planned against a guess is not a design.
- **Remove instrumentation** that was only there to find the cause before the first fix unit starts. It does not ship.
- **Plan the fix.** The plan goes in 設計, and its pieces become the units of `実装`.

### refactoring

- **Create the worktree first.**
- **Write the pin yourself**: a characterization test, snapshot, or equivalence harness that captures current behavior. Commit it on its own before any structure moves, and tick the sub-item. Type check and lint are not a pin.
- If the cleanup uncovers a missing feature or a real bug, split it into its own flow. This one ships the structural change against the pinned contract.
- The last unit of `実装` is the session's own check that the change lowered reader load somewhere. If it did not, revert it.

### generic

One sub-item. Decide what changes, where, and how it will be shown to work. Nothing else is required beyond the reduced list below.

### figure-it-out

Follow that skill's Phase A and Phase B. The phase list Phase B designs becomes the units of `実装`.

## Settling forks

- **An experiment can settle it** → prototype it per `playbooks/prototype.md`, in a scratch directory outside the repo. Do not ask. Record what was observed.
- **A product or preference call** → ask the user. This is the only kind of question Design asks.
- **A shape with no precedent** → build two or three competing sketches before committing.

## What 設計 must hold

Design is done when `## 設計` in the issue states these. Keep each to a few lines.

| | Item | `generic` |
|---|---|---|
| 1 | **The shape.** The data shape and the structure that organizes it, the chosen design, and the alternative that was rejected with the reason | What changes and where, in a sentence or two |
| 2 | **The done predicate.** One falsifiable statement of what will be observed on the real artifact when the whole change works. Verify checks this | required |
| 3 | **The units.** Written into 手順 under `実装`, each with a `verify:` line, ordered so the sequence proves itself: the subtraction before the addition, the baseline before the treatment | required; often one unit |
| 4 | **The throughput checkpoint.** Which units are independent and which serialize, and why | omit |
| 5 | **Irreversible steps.** Each one named, with a `⏸ 承認` item directly before its unit. "None" is a valid answer | required |
| 6 | **Size.** Rough units and effort. If the run will take hours, say so | omit |

Then:

1. Update the body: 設計, the units, tick `設計`, set `stage: build`.
2. Post the "Design recorded" comment with the decisions the body does not show.
3. Tell the user in a few lines what was chosen and where the issue is.
4. **Proceed to Build.** The one exception is a run sized at hours without a session override: present the framing and wait once.

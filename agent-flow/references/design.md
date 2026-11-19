# agent-flow: Frame and Design

Both stages run in the agent-flow session itself, in the main repo, without writing to it. The design is never handed to a subagent. Subagents may gather: tracing a large subsystem or parsing a long ticket can be delegated, with the summary kept in the session.

## Frame

1. **Resolve pstack and read the adapter and `poteto-mode/SKILL.md`** (`references/pstack.md`). Run the issue preflight (`references/issue.md`).
2. **Restate the goal and the smallest change that meets it.** This is poteto-mode's first non-negotiable. The restatement becomes `## 目的`.
3. **Take in what already exists.** A plan approved in plan mode, a design worked out earlier in the conversation, or a ticket is **input**. Do not redo it and do not treat it as finished: Design checks it against what the playbook requires and fills only the gaps. Pull a ticket with `gh issue view` and distill it.
4. **Pick the playbook** (the table in SKILL.md) and read its file in full.
5. **Derive the slug and branch.** A short kebab-case slug from the subject of the work; branch `<type>/<slug>`. If the branch or a worktree for it already exists, stop and ask whether to resume or rename. Never reuse one silently.
6. **Create the tracking issue** from `templates/ISSUE.md`: the meta block with `stage: design`, 目的, and the playbook's steps copied into 手順 with the four tail items. Leave 設計 as a one-line placeholder. Apply the `agent-flow` label.

Then go straight into Design. Do not hand off and do not ask to proceed.

## Design

Run the playbook's steps that come before code is delegated, ticking each in the issue as it completes. What those steps are depends on the playbook.

### feature

Playbook steps 1–3: trace the affected subsystem, run `architect` for the shape, write the throughput checkpoint.

- `architect` sketches **two** shapes and picks one. Record both. When the design is large or contested, `architect` routes to `arena`; a non-Claude runner seat follows `references/pstack.md`.
- The throughput checkpoint is four items, each answered or marked `n/a: <reason>`: blocking first steps, independent workstreams, shared mutable state, smallest safe decomposition.

### bug-fix

Playbook steps 1–3: reproduce it yourself on the real surface, binary-search the cause to one mechanism confirmed by runtime evidence, plan the fix.

- Reproduction and instrumentation write files, so **create the worktree now** (`references/build.md`, "The worktree") and work in it from here on.
- The reproduction is the first unit and its commit lands before the fix in history.
- Design is not complete until the surviving mechanism is confirmed by a run. A fix planned against a guess is not a design.

### refactoring

Playbook steps 1–3: pin the behavior contract, name the structure the code is missing, name the target shape.

- The pin (characterization test, snapshot, or equivalence harness) writes files, so **create the worktree now**. The pin is the first unit and lands before any structure moves.
- If the cleanup uncovers a missing feature or a real bug, split it into its own flow. This one ships the structural change against the pinned contract.

### generic

No playbook file. Write one paragraph: what changes, where, and how it will be shown to work. Skip to "What 設計 must hold."

### figure-it-out

Follow that skill's Phase A and Phase B. Its designed phase list becomes the top-level items of 手順, replacing the placeholder steps written at Frame.

## Settling forks

- **An experiment can settle it** → prototype it per `playbooks/prototype.md`, in a scratch directory outside the repo. Do not ask. Record what was observed.
- **A product or preference call** → ask the user. This is the only kind of question Design asks.
- **A shape with no precedent** → build two or three competing sketches before committing.

## What 設計 must hold

Design is done when `## 設計` in the issue states all of these. Keep each to a few lines.

1. **The shape.** The data shape and the structure that organizes it, the chosen design, and the alternative that was rejected with the reason.
2. **The done predicate.** One falsifiable statement of what will be observed on the real artifact when the whole change works. This is what Verify checks.
3. **The units.** The decomposition, written into 手順 as nested items, each with a `verify:` line. Order them so the sequence proves itself: the failing test before the fix, the pin before the reshape, the subtraction before the addition.
4. **The throughput checkpoint.** Which units are independent and which serialize, and why.
5. **Irreversible steps.** Each one named, with a `⏸ 承認` item placed directly before it in 手順. "None" is a valid answer.
6. **Size.** Rough units and effort. If the run will take hours, say so.

Then:

1. Update the body: 設計, the units, `stage: build`.
2. Post the "Design recorded" comment with the decisions the body does not show.
3. Tell the user in a few lines what was chosen and where the issue is.
4. **Proceed to Build.** The one exception is a run sized at hours without a session override: present the framing and wait once.

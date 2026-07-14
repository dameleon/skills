# Sample coder subagents (`senior-coder` / `generic-coder`)

Two **implementation** subagents that give agent-flow a *stable, real* `subagent_type`
in both Claude Code and Cursor, so a code-producing role never dispatches to a
non-existent agent (e.g. the Cursor-ism `coder`, which is a hard error in Claude Code).
They differ by **model tier** — `senior-coder` for design-heavy / cross-cutting work,
`generic-coder` for well-specified routine work.

These are **samples for manual install**, not auto-installed. Copy them and adjust the
`model:` field to taste — the values below are illustrative.

## Install (manual)

| Runtime | Personal (all projects) | Project | Source |
|---|---|---|---|
| Claude Code | `~/.claude/agents/` | `.claude/agents/` | `claude-code/*.md` |
| Cursor | `~/.cursor/agents/` | `.cursor/agents/` | `cursor/*.md` |

```bash
# Claude Code (personal)
cp claude-code/senior-coder.md  claude-code/generic-coder.md  ~/.claude/agents/
# Cursor (personal)
cp cursor/senior-coder.md       cursor/generic-coder.md       ~/.cursor/agents/
```

Identity comes from the `name:` frontmatter, not the filename — keep `name`
values exactly `senior-coder` / `generic-coder` so agent-flow's preference picks them up.

## How agent-flow uses them

agent-flow defaults to the always-present `general-purpose`; if these two are defined it
**prefers** them for `@implement` / `@fix` / `@refactor` (generic by default, senior for
heavy work). Nothing breaks if they are absent — that is the portability contract
(the agent-flow skill's `run.md`). The model tier is the main differentiator; the system prompt also
bakes in the "act, don't just report" and "a red lint may be tooling noise" guards that
caused empty-handed subagent reports.

## Model field (adjust freely)

- Claude Code: `opus` / `sonnet` / `haiku` / `fable` / a full id (`claude-opus-4-8`) / `inherit`.
- Cursor: `inherit` / `fast` / a specific model id.

---

# Delegation subagent: `cursor-delegate`

The canonical executor for the `cursor-delegate` skill (`skills/cursor-delegate/`) — unrelated to
agent-flow. It offloads a small, goal-clear task to the Cursor agent CLI (`cursor-agent`)
headlessly, then independently acceptance-checks the result against the real files before reporting a
concise verdict, keeping the routine work out of the caller's context. Scoped to `Bash, Read, Grep,
Glob` (no Edit/Write) so it can only delegate-and-verify, never hand-implement.

Two ways it gets used, both landing on this same role:
- **Direct dispatch** — the main agent picks `subagent_type: cursor-delegate` via the Agent tool
  whenever it judges a task simple enough to offload.
- **Via the skill** — `skills/cursor-delegate/SKILL.md` forks into it (`context: fork` +
  `agent: cursor-delegate`), injecting the task.

**Install is required** for the skill (it forks into this agent; an unknown agent type is a hard
error, not a silent fallback):

```bash
# Claude Code (personal)
cp claude-code/cursor-delegate.md  ~/.claude/agents/
# Cursor (personal) — see the note in the file; intended for a Claude Code host calling Cursor
cp cursor/cursor-delegate.md       ~/.cursor/agents/
```

Keep the `name:` value exactly `cursor-delegate` so the skill's `agent: cursor-delegate` and direct
`subagent_type: cursor-delegate` dispatch both resolve to it. `cursor-agent` itself must be installed
and logged in (`cursor-agent status`).

---

# Advisor subagent: `advisor`

A **second opinion** on the main session's work — stands in for Claude Code's built-in
`advisor` tool, which routes to a model per-install and can be unavailable. This one pins
**`model: fable`** (Fable 5) explicitly, so it neither breaks nor silently downgrades. Scoped to
`Read, Grep, Glob, Bash` — no Edit/Write, and the prompt holds `Bash` to inspection-only, so it
critiques and never implements. (This is "no file edits + a prompt convention," not a mechanical
read-only sandbox: `Bash` could still mutate, so don't grant it `bypassPermissions`.)

**What it does not get:** the main conversation. A subagent dispatched via the Agent tool receives
only the prompt the caller hands it, not the transcript (that auto-inheritance is exclusive to
`subagent_type: fork`, which is locked to the caller's model and so can't run Fable). So the caller
passes a context bundle — the task, the current approach, the files/diff to review — and the advisor
reads the rest itself (`git diff`, `git log`, `rg`, file reads). The system prompt bakes in
"challenge by default, don't rubber-stamp; cite `file:line`; read-only."

**When it fires:** the `description` mirrors the built-in advisor's cadence — before committing to an
approach, before declaring a task done, and when stuck — so Claude auto-delegates at those moments.
You can also invoke it explicitly with `@advisor` or by naming it in a prompt.

## Install (symlink — this repo is the source of truth)

```bash
# Claude Code (personal); edits to the repo file stay live via the symlink.
# Use an absolute target so the link never dangles regardless of cwd:
ln -s "$(git rev-parse --show-toplevel)/agents/claude-code/advisor.md" ~/.claude/agents/advisor.md
```

Claude-Code-only (no `cursor/` variant): the point is pinning Fable 5, which is a Claude model alias.

## Model / effort (adjust freely)

`model: fable` is the deliberate choice here. To make the review deeper, add `effort: high` (or
`max`) to the frontmatter — available effort tiers depend on the model, so drop it back to plain
`model: fable` if a tier is rejected.

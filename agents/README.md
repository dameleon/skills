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

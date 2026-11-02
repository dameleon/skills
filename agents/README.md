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
| Claude Code | `$CLAUDE_CONFIG_DIR/agents/` (default `~/.claude/agents/`) | `.claude/agents/` | `claude-code/*.md` |
| Cursor | `$CURSOR_CONFIG_DIR/agents/` (default `~/.cursor/agents/`) | `.cursor/agents/` | `cursor/*.md` |

Symlink rather than copy, so edits in this repo take effect without reinstalling:

```bash
# Claude Code (personal) — run from this agents/ directory
mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents"
ln -s "$PWD"/claude-code/{senior-coder,generic-coder}.md "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents/"
# Cursor (personal)
mkdir -p "${CURSOR_CONFIG_DIR:-$HOME/.cursor}/agents"
ln -s "$PWD"/cursor/{senior-coder,generic-coder}.md "${CURSOR_CONFIG_DIR:-$HOME/.cursor}/agents/"
```

When a workspace sets `CLAUDE_CONFIG_DIR` / `CURSOR_CONFIG_DIR`, `~/.claude/agents/` is **not**
read — install under the config dir, or the agent type silently does not exist.

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

- Claude Code: `opus` / `sonnet` / `haiku` / `fable` / a full id (`claude-sonnet-5-5`) / `inherit`.
  `inherit` means "whatever the parent session runs" — on a Fable / Opus session that is the most
  expensive tier, so name a model explicitly for routine roles. Agents that leave `model` unset fall
  back to `CLAUDE_CODE_SUBAGENT_MODEL` when it is set (e.g. `"env": {"CLAUDE_CODE_SUBAGENT_MODEL":
  "sonnet"}` in `settings.json`).
- Cursor: `inherit` / `fast` / a specific model id.

---

# Retired (Claude Code): `cursor-delegate` subagent

The Claude Code `cursor-delegate` subagent is **removed**. It inherited the caller's model, so a
Fable / Opus session paid frontier-model tokens just to shepherd a cheap `cursor-agent` run. The
`cursor-delegate` skill now calls its bundled `scripts/delegate.sh` directly — no Claude model sits
between the caller and Cursor (see `skills/cursor-delegate/reference.md`). Delete any leftover
`$CLAUDE_CONFIG_DIR/agents/cursor-delegate.md` symlink.

The Cursor-host variant `cursor/cursor-delegate.md` is still here, for the rare case where one
Cursor agent should drive another headless `cursor-agent`.

---

# Retired: `advisor` subagent

A Fable-pinned `advisor` subagent used to live here, standing in for Claude Code's built-in
`advisor` tool back when that tool routed to a per-install model and could fail with
"Advisor unavailable." **It is removed.** The built-in advisor now ships as a native plugin and its
model is pinned in `~/.claude/settings.json` (`"advisorModel": "fable"`), so the subagent bought
nothing and cost context fidelity: a subagent sees only the bundle the caller hands it, while the
built-in tool sees the whole transcript. Delete any leftover `~/.claude/agents/advisor.md` symlink.

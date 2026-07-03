---
name: cursor-delegate
description: >-
  Offload a well-scoped, self-contained task to the Cursor agent CLI (`cursor-agent`) via the
  `cursor-delegate` subagent, which runs it headlessly and independently acceptance-checks the result
  before reporting a concise verdict — so the routine work and its verbose output stay OUT of your
  main context. Use this whenever you judge a task simple and goal-clear enough to hand off and
  verify: localized code edits, mechanical refactors, boilerplate / scaffolding, format / lint fixes,
  a focused test, a small script, or a contained bug fix. Default model is `auto` (cheap; escalates
  to Composer 2.5 only when flagged hard, falls back to `auto` on limit / cost errors). Trigger
  phrases: "cursorに投げて", "cursor-agentに任せて", "これは簡単だからcursorに委譲", "delegate to cursor",
  "offload to cursor", "サブエージェント的にcursorで", "context節約のためcursorへ". Do NOT use for ambiguous
  specs, large cross-cutting refactors, or security-sensitive changes — keep those yourself.
argument-hint: "[task to delegate]  (optional hints: model=composer, accept=<done-criterion>)"
context: fork
agent: cursor-delegate
---

# Cursor Delegate

This skill is a thin entry point. Its content is injected into the **`cursor-delegate` subagent**,
which carries the full workflow (frame → dispatch to `cursor-agent` → acceptance-check the real
files → resume-fix up to 2 rounds → report). The subagent is also dispatchable on its own — the main
agent can pick it via the Agent tool whenever it judges a task simple enough to offload. Either path
lands on the same delegation contract.

## Task

Delegate the following to `cursor-agent` and return only a concise verdict:

> $ARGUMENTS

Optional hints in the task text:
- `model=composer` — escalate from `auto` to Composer 2.5 for a harder task (otherwise stay on
  `auto`; on a limit / cost error, fall back to `auto`).
- `accept=<criterion>` — pin the done-criterion you will verify against; otherwise derive the
  smallest objective check that proves the goal.

Follow your operating contract: **delegate the doing, verify it against the real files, never trust
`cursor-agent`'s own success message.** If the task is ambiguous, security-sensitive, or too large
to state a done-criterion for, stop and report that instead of delegating.

## Prerequisite

This skill forks into the `cursor-delegate` subagent, so that subagent must be installed at
`~/.claude/agents/cursor-delegate.md` (or `.claude/agents/`) — an unknown agent type is a hard
error, not a silent fallback. See `agents/README.md` for the one-line install. `cursor-agent` itself
must be installed and logged in (`cursor-agent status`).

## Reference

For the full `cursor-agent` flag set, the model tier table, the JSON result schema, error / limit
detection patterns, and worktree / sandbox notes, read `reference.md` in this skill directory.

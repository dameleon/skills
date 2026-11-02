---
name: cursor-delegate
description: >-
  Offload a well-scoped task straight to the Cursor agent CLI (`cursor-agent`) via a bundled script
  that dispatches it headlessly, runs your objective acceptance check, resume-fixes on failure, and
  prints a short verdict. No Claude subagent sits in between, so the work costs Cursor tokens, not
  Claude tokens, and its verbose output stays out of your context. Use whenever a task is simple and
  verifiable with one shell command: localized edits, mechanical refactors, boilerplate, format /
  lint fixes, a focused test, a small script, a contained bug fix. Model `auto` by default
  (Composer 2.5 when flagged hard). Triggers: "cursorに投げて", "cursor-agentに任せて",
  "これは簡単だからcursorに委譲", "delegate to cursor", "offload to cursor", "context節約のためcursorへ".
  Not for ambiguous specs, large cross-cutting refactors, security-sensitive changes, or work with
  no objective shell check.
argument-hint: "[task to delegate]  (optional hints: model=composer, accept=<shell check>)"
---

# Cursor Delegate

Hand the task to `cursor-agent` through `scripts/delegate.sh`. The script owns the whole loop —
dispatch → run the acceptance check → on failure `--resume` the same Cursor session with the failing
output (max 2 rounds) → print a verdict. It contains no LLM: the acceptance decision is the check's
exit code, and the fix prompt is built mechanically from the check's output. Your job is only to
frame the task, pick the check, and read the verdict.

Task: $ARGUMENTS

## 1. Frame (you, before dispatch)

- **Task** — restate it as one self-contained instruction `cursor-agent` can act on without asking
  questions (it runs headlessly). Name the files to touch and say "do not touch other files" when
  scope matters.
- **Acceptance check** — one shell command whose exit 0 proves the goal: the relevant test, a build,
  lint on the touched files, or a small `python3 -c` / `grep -q` assertion. If the caller passed
  `accept=...`, use it. It must not be something `cursor-agent` can trivially satisfy by editing the
  check itself (point at an existing test, or assert on behavior, not on a file it writes).
- **Refuse** when no objective check exists ("make comments friendlier", "improve readability"),
  when the spec is ambiguous, or when the change is security-sensitive or destructive. Do it yourself
  or ask; never invent a weak proxy check to manufacture a PASS.
- `cursor-agent` edits the current directory and inherits its branch / worktree. If you are on a
  protected branch and the change is non-trivial, set up the worktree first and pass `--workdir`.

## 2. Dispatch (one Bash call)

```bash
"<skill-dir>/scripts/delegate.sh" --workdir "<abs repo or worktree path>" \
  --accept '<shell check>' [--model composer-2.5] [--rounds 2] \
  -- "<self-contained task>"
```

- `<skill-dir>` is the directory containing this SKILL.md.
- Use a generous Bash timeout (`600000`) or `run_in_background` — real tasks take minutes.
- `--model composer-2.5` only when the caller passed `model=composer`; otherwise leave the default
  `auto`. A limit / availability error on a non-`auto` model retries once on `auto` automatically.

Exit codes: `0` PASS, `1` NG (check still failing after the fix rounds), `2` usage / preflight,
`3` cursor-agent error (auth, limit, crash — read the `acceptance:` line).

## 3. Read the verdict

The script prints only this (full transcripts stay in the `logs:` directory):

```
status: done | failed
model: <cursor model used>
changed: <files cursor-agent touched; pre-existing dirt excluded>
check artifacts: <files the check itself produced, e.g. __pycache__ — not cursor's edits>
acceptance: PASS — `<check>` exit 0 | NG — <why>
fix rounds: <n>
session: <id — `cursor-agent --resume <id>` for follow-up>
cursor summary: <cursor's own final message, truncated; a claim, not evidence>
logs: <dir>
```

- **PASS** — confirm `changed:` stays within the task's scope. Look at the diff only if the list is
  surprising; the check already proved the goal, so don't re-audit.
- **NG / failed** — relay the gap. Do not hand-fix silently; tell the user the delegation did not
  take, then decide whether to do it yourself.
- `exit 2` with `cursor-agent not found` / `not logged in` → the user installs it or runs
  `cursor-agent login` themselves.

## Reference

Flag set, model tiers, JSON schema, error classification, permission setup for auto mode, and
worktree / sandbox notes: `reference.md` in this skill directory.

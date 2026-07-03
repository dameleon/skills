# Reference: cursor-delegate

Detailed reference for driving `cursor-agent` headlessly. The SKILL.md body has the workflow; this
file is the lookup table — read it when you need a specific flag, the JSON schema, or the failure
handling rules.

## Table of contents

- [Command anatomy](#command-anatomy)
- [Flags that matter here](#flags-that-matter-here)
- [Model tiers & escalation](#model-tiers--escalation)
- [JSON result schema](#json-result-schema)
- [Error & limit detection](#error--limit-detection)
- [Resume (continuing a session)](#resume-continuing-a-session)
- [Worktree & cwd](#worktree--cwd)
- [Sandbox & force safety](#sandbox--force-safety)
- [Troubleshooting](#troubleshooting)
- [Companion subagent](#companion-subagent)

## Command anatomy

```bash
cursor-agent -p --output-format json -f --trust --model <MODEL> "<TASK PROMPT>"
```

`cursor-agent` and `agent` are the same binary. The prompt is a positional argument; pass the whole
self-contained instruction as one quoted string. Redirect stdout to a file and read it back rather
than relying on `jq` being installed:

```bash
TMP="$(mktemp -d)"   # scratch outside the repo so it never dirties git status
cursor-agent -p --output-format json -f --trust --model auto "<task>" \
  > "$TMP/cursor.json" 2> "$TMP/cursor.err"; echo "exit=$?"
```

## Flags that matter here

| Flag | Why we use it |
|---|---|
| `-p`, `--print` | Headless / non-interactive. **Has access to all tools, including write and shell.** Required for scripted use. |
| `--output-format text\|json\|stream-json` | Use `json`: emits a single result object (final message + metadata). `text` prints only the final text; `stream-json` emits deltas (not needed here). |
| `-f`, `--force` (alias `--yolo`) | Auto-approve tool/shell calls. Without it a headless run hangs at the first approval prompt. |
| `--trust` | Trust the workspace without prompting. Only works with `-p`. |
| `--model <model>` | Pick the model. `auto` by default. See model table below. |
| `--resume [chatId]` | Continue a prior session by id (from `session_id`). Used for the fix loop. |
| `--mode plan\|ask` | Read-only modes — `ask` (Q&A) / `plan` (analyze, no edits). Use only if the delegated task is itself read-only (rare for this skill). |
| `--sandbox enabled\|disabled` | Force sandbox on/off. See safety note. |
| `-w`, `--worktree [name]` | Run in an isolated git worktree at `~/.cursor/worktrees/<repo>/<name>`. Off by default here. |
| `--workspace <path>` | Working directory. Defaults to current directory — usually leave it. |

`--list-models` / `cursor-agent models` prints the available models. `cursor-agent status` shows
auth state.

## Model tiers & escalation

Policy: **default `auto`, escalate only when flagged, fall back to `auto` on limit/cost errors.**

| Use | Model value | Notes |
|---|---|---|
| Default | `auto` | "Auto (current)". Cheap; routes hard prompts to capable models on its own. Start here. |
| Escalation (this skill's choice) | `composer-2.5` | Cursor-native, coding-tuned, low cost, low limit-risk. The deliberate step up from `auto` for a task flagged hard. |
| Heavier alternatives (not default) | `gpt-5.5-high`, `claude-opus-4-8-high`, `gpt-5.3-codex-high` | Stronger but high cost and real limit-reach risk on the org account. Use only on explicit request. |

Parameterized models accept bracket overrides, e.g.
`'claude-opus-4-8[context=1m,effort=high,fast=false]'` — quote them.

**Escalation trigger:** the *caller* (which judged the task borderline) is better placed than this
fork to know it's hard. So escalate when `$ARGUMENTS` carries `model=composer` (or the caller named
a model), or when the task is plainly beyond `auto`. Otherwise stay on `auto`. This skill exists for
*simple* work — escalation is the exception.

## JSON result schema

`--output-format json` emits one object:

```json
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "duration_ms": 14914,
  "duration_api_ms": 14914,
  "result": "OK",
  "session_id": "142ebc8e-6558-468b-8710-11d6ced34d18",
  "request_id": "e7f991e4-...",
  "usage": { "inputTokens": 50152, "outputTokens": 41, "cacheReadTokens": 5994, "cacheWriteTokens": 0 }
}
```

| Field | Use |
|---|---|
| `result` | The agent's final message. A *summary*, not proof — verify against real files (SKILL.md Step 3). |
| `is_error` / `subtype` | Failure signal. Failed if `is_error` true or `subtype` ≠ `"success"`. |
| `session_id` | Pass to `--resume` for the fix loop or further caller follow-up. |
| `usage` | Token accounting if the caller wants cost reported. |

## Error & limit detection

A run failed if **any** of: shell `exit` ≠ 0, `is_error: true`, or `subtype` ≠ `"success"`. When it
fails, read `result` and `$TMP/cursor.err` and classify:

- **Limit / cost / availability** — keywords like `rate limit`, `usage limit`, `quota`,
  `exceeded`, `not available`, `unavailable`, `insufficient`, `402`, `429`, `unauthorized`,
  `payment`. → If you used a non-`auto` model, **retry once with `--model auto`**. If `auto` also
  hits this, abort and report (the account is out of budget — the caller decides).
- **Auth** — `not logged in`, `login`, `authenticate`. → Abort and report: the user must run
  `cursor-agent login` themselves (don't try to auth on their behalf).
- **Task failure** (it ran but couldn't do the work) — feed the specifics into the resume fix loop
  (SKILL.md Step 4).

Match keywords case-insensitively and treat the list as indicative, not exhaustive.

## Resume (continuing a session)

```bash
cursor-agent -p --output-format json -f --trust --resume "$SESSION_ID" "<fix instruction>"
```

`--resume <id>` keeps the prior session's context, so the agent already knows what it built — much
cheaper and more accurate than re-explaining from scratch. The caller can also `--resume` the same
`session_id` later for follow-up work, which is why Step 5 reports it.

## Worktree & cwd

`cursor-agent` edits files in the current directory (`--workspace` defaults to cwd), so it inherits
the caller's branch / worktree. Default behavior here: **do not** create a separate worktree — let
edits land where the caller already is.

Two cases to be aware of:
- The repo's global rule prefers isolating file-changing work in a git worktree. If the caller is
  on a protected branch (`main` / `master` / `develop`) and the change is non-trivial, the *caller*
  should set up the worktree before delegating; this fork then inherits it.
- `cursor-agent -w` creates a worktree under `~/.cursor/worktrees/<repo>/<name>` — a **different**
  location from the repo's own `.wt/`. Use it only when the task explicitly asks for Cursor-managed
  isolation, and report the path so the result isn't lost.

## Sandbox & force safety

`-f` / `--force` lets the agent run arbitrary shell unattended. That is what makes headless
delegation work, but it is also the main risk surface — only delegate tasks you would let run shell
without watching. For extra containment, `--sandbox enabled` restricts the agent, but it can block
legitimate builds / installs, so it is not the default. `--auto-review` (server-classified
auto-approval) prompts for unsafe calls, which would **hang** a headless run — avoid it here.

## Autonomous / headless host: pre-authorize the CLI

When the **caller** Claude Code runs autonomously (headless, or `defaultMode: "auto"`), its
auto-mode classifier vets every shell command. An unlisted `cursor-agent` call — especially with
`-f --trust`, which hands an external agent unrestricted shell — is classified unsafe and
**denied**, so the delegation never dispatches. The same classifier also blocks the caller from
editing its own `settings.json` to widen permissions mid-run (a `[Self-Modification]` denial), so
this is **not** something the run can fix dynamically — the user must set it up beforehand:

- `permissions.allow`: add `Bash(cursor-agent:*)` and `Bash(agent:*)` (`agent` is the same binary).
  Listed allow rules bypass the classifier under `defaultMode: "auto"`.
- `sandbox.excludedCommands`: add `cursor-agent:*` and `agent:*`, or the sandbox blocks Cursor's
  API traffic (its host is not in `allowedDomains`). This mirrors how `codex` / `gemini` are set up.

With the `TMP=…; cursor-agent …` compound dispatch, the allow rule still matches the `cursor-agent`
segment, but running `cursor-agent` as its own line is the cleanest match.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Run hangs | Missing `-f` (waiting on approval) or `--auto-review` in headless mode. Use `-f --trust`. |
| Denied under auto / autonomous mode (`[Self-Modification]` or classifier denial) | Caller is autonomous and `cursor-agent` isn't pre-authorized; the classifier also blocks fixing `settings.json` mid-run. User must pre-authorize beforehand (see "Autonomous / headless host"). |
| `command not found: cursor-agent` | Not installed / not on PATH (`~/.local/bin`). Report to user. |
| `not logged in` | `cursor-agent login` — user runs it themselves (browser auth). |
| Empty / non-JSON stdout | Check `$TMP/cursor.err` and `exit` code; the run likely errored before producing a result. |
| Timeout | Default Bash timeout is too short for real tasks. Raise it (`timeout: 600000`) or run in background. |

## The cursor-delegate subagent (canonical executor)

The full delegation workflow lives in the **`cursor-delegate` subagent**, not in the skill. The
subagent (`agents/claude-code/cursor-delegate.md`, with a Cursor variant at
`agents/cursor/cursor-delegate.md`) is the canonical executor and the reusable `subagent_type`:

- The main agent can **dispatch it directly** via the Agent tool whenever it judges a task simple
  enough to offload — no skill needed.
- The **skill** (`SKILL.md`) is a thin entry point that forks into this subagent (`context: fork` +
  `agent: cursor-delegate`); the skill content is injected into the subagent.

Because the skill forks into it, the subagent is a **prerequisite**, not an optional add-on: install
`agents/claude-code/cursor-delegate.md` to `~/.claude/agents/` (or `.claude/agents/`). An unknown
agent type is a hard error — the skill will not silently fall back. The subagent is scoped to
`Bash, Read, Grep, Glob` (no Edit/Write) so it can only delegate-and-verify, never hand-implement.
See `agents/README.md` for install.

---
name: cross-review
description: >
  Review any content (files, code, diffs) using external LLM CLIs (Codex, Gemini).
  Supports multiple review focuses: code, architecture, security, performance, test, requirements, design.
  Use --cli to select which LLM to use (default: codex only). Use --output <path> to write the report to a file.
  After review, fixes are auto-applied by rule-based severity policy (see Step 5). Use --no-fix to output report only.
argument-hint: "[target] [--focus type] [--cli codex|gemini|all] [--model name] [--no-fix] [--output path] [--codex-opts '...'] [--gemini-opts '...']"
# NOTE: --model is rejected when --cli all (model namespaces differ between CLIs)
---

Review any content using external LLM CLIs and produce a structured report.

## Step 1: Parse Arguments and Validate

> **Invocation-level validation is the single source of truth here.** All "is this invocation runnable?" checks live in this step and MUST complete before any filesystem write or external process is launched. Downstream steps (Step 2 onward) assume validation passed and do not re-check.

Parse `$ARGUMENTS` for the following flags (order-independent):

| Flag | Description | Default |
|---|---|---|
| `--focus <type>` | Review focus type | `general` |
| `--cli <name>` | CLI to use: `codex`, `gemini`, `all` | `codex` |
| `--model <name>` | Model name passed to codex via `-c model="<name>"`, to gemini via `-m`. **Rejected when `--cli all`** (use `--codex-opts`/`--gemini-opts` instead) | (CLI default) |
| `--no-fix` | Report only — skip all fix application | `false` |
| `--output <path>` | Write report to file instead of inline | (inline) |
| `--codex-opts '<opts>'` | Raw options appended to codex command | (none) |
| `--gemini-opts '<opts>'` | Raw options appended to gemini command | (none) |

Everything not matching a flag is treated as the target.

### Target Resolution (priority order)

Resolve in this order — first match wins:

1. **Flags**: `--diff`, `--diff-staged`, `--diff <ref>`
2. **File paths / glob patterns**: explicitly provided paths
3. **Default**: all working changes

| Argument | Interpretation |
|---|---|
| (none) | All working changes (see default target resolution below) |
| `--diff` | `git diff` (unstaged only) |
| `--diff-staged` | `git diff --staged` (staged only) |
| `--diff <ref>` | `git diff <ref>` (e.g., `--diff main`, `--diff HEAD~3`) |
| file path | That file |
| glob pattern | Expand, exclude binaries via `file --mime-type`, sort paths |

**Default target resolution** (when no argument):
1. `git diff HEAD` で差分があるか確認
2. `git ls-files --others --exclude-standard` で untracked ファイルを取得
3. untracked ファイルはバイナリを `file --mime-type` で除外
4. 両方のリストを結合してレビュー対象とする

### Focus Type (default: `general`)

Valid values: `general`, `code`, `architecture`, `security`, `performance`, `test`, `requirements`, `design`

### Pre-execution Validation (single source of truth)

Run all checks below **before** proceeding to Step 2. No filesystem writes, no external commands beyond `which`/`file`/`git` introspection. On any failure: surface the error to the user with the resolution hint, then STOP — do not continue to Step 2 / 3.

1. **Target not empty**: empty diff, no matching file, no glob match → error.
2. **Focus is valid**: one of the 8 values above → otherwise error listing the valid set.
3. **Glob expansion safety**: when target is a glob, expand → filter binaries via `file --mime-type` → sort alphabetically. Empty post-filter set is also a Target-not-empty failure.
4. **`--cli all` + `--model` conflict**: reject with this resolution message — "Codex and Gemini use different model namespaces. Use `--codex-opts '-c model=\"<name>\"'` and/or `--gemini-opts '-m <name>'` instead."
5. **Forbidden CLI-specific options** (these break the skill's guarantees, so they cannot be passed through):
   - Codex (`--codex-opts`): `--uncommitted`, `--base`, `--commit`, `--title` (conflict with prompt-based target handling), `-c sandbox_permissions` (overrides read-only guarantee)
   - Gemini (`--gemini-opts`): `--approval-mode`, `-y`, `--yolo` (conflicts with always-included `--approval-mode yolo`), `--output-format`, `-o` (breaks text parsing)
   - On detection: error and stop.
6. **Selected CLI(s) installed**:
   - `which codex 2>/dev/null` if codex is selected (default, or via `--cli codex|all`)
   - `which gemini 2>/dev/null` if gemini is selected (via `--cli gemini|all`)
   - Missing → error and stop.

If all 6 checks pass, proceed to Step 2.

## Step 2: Build Review Prompt

1. Read `review-prompts.md` in this skill directory for the base template
2. Read `review-focuses.md` in this skill directory, extract the section matching the focus type
3. Replace `[REVIEW_FOCUS]` with the extracted focus section
4. Replace `[REVIEW_TARGET]` with the target instruction. The instruction text is composed from the conditions below; the external CLI is the reader, so word it as a directive to that CLI:
   - **File paths** (explicit paths or post-glob expansion): `Review the following files: <path1>, <path2>, ... — read each file directly from the filesystem.` (The external CLI does the read; this skill does NOT inline file contents into the prompt.)
   - **Diff flag** (`--diff` / `--diff-staged` / `--diff <ref>`): `Run '<git diff command>' in the project directory and review the output.`
   - **Default** (no argument) — compose conditionally from the two independent clauses below; emit only the clauses that apply, joined by a blank line:
     - *(if `git diff HEAD` is non-empty)* `Run 'git diff HEAD' in the project directory and review the output.`
     - *(if there are untracked text files after the `file --mime-type` binary filter)* `Also review these untracked files (read each from the filesystem): <path1>, <path2>, ...`
     - If neither clause applies, Step 1 validation #1 (Target not empty) would have already halted execution before this step.
5. Write the assembled prompt to `/tmp/cross-review-${CLAUDE_SESSION_ID}/prompt.txt` (`mkdir -p` the directory first)

## Step 3: External LLM Review

(CLI selection, conflicts, forbidden opts, and availability were all validated in Step 1 — do not re-check here.)

### CLI Selection

| `--cli` value | Behavior |
|---|---|
| `codex` (default) | Codex only |
| `gemini` | Gemini only |
| `all` | Both in parallel |

### Build CLI Commands

Base commands (prompt is always passed via stdin; target details are embedded in the prompt):

- **Codex**: `cat /tmp/cross-review-${CLAUDE_SESSION_ID}/prompt.txt | codex review -c 'sandbox_permissions=["disk-full-read-access"]' [options] -`
- **Gemini**: `cat /tmp/cross-review-${CLAUDE_SESSION_ID}/prompt.txt | gemini --approval-mode yolo`

Codex `-` reads custom review instructions from stdin. Gemini reads stdin automatically when no `-p` argument is given. Codex sandbox is restricted to read-only via `-c sandbox_permissions` to prevent unintended file modifications during review.

> **Note**: `codex review` native target flags (`--uncommitted`, `--base`, `--commit`) cannot be combined with a custom prompt (`-` or `[PROMPT]`). Since this skill always passes a review focus prompt, all targets are handled via prompt instructions instead.

Apply options in this order (`--model` and CLI-specific opts have already passed Step 1 validation):

1. **`--model`** (when set; mutually exclusive with `--cli all`, already rejected in Step 1):
   - Codex: `cat /tmp/.../prompt.txt | codex review -c 'sandbox_permissions=["disk-full-read-access"]' -c model="<model>" -`
   - Gemini: `cat /tmp/.../prompt.txt | gemini --approval-mode yolo -m <model>`

2. **CLI-specific options** (`--codex-opts` / `--gemini-opts`): append raw options (forbidden values already rejected in Step 1).
   - Codex: `cat /tmp/.../prompt.txt | codex review -c 'sandbox_permissions=["disk-full-read-access"]' <codex-opts> -`
   - Gemini: `cat /tmp/.../prompt.txt | gemini --approval-mode yolo <gemini-opts>`

Commonly useful CLI options for reference:

| Codex option | Description |
|---|---|
| `-c model="<name>"` | Model selection |
| `-c key=value` | Override config value |
| `--enable <feature>` | Enable a feature |
| `--disable <feature>` | Disable a feature |

| Gemini option | Description |
|---|---|
| `-m <model>` | Model selection |
| `-s` | Enable sandbox |

### Run Review

Run reviews (timeout: 300s each). If `--cli all`, run in parallel:

- **Codex**: `cat /tmp/cross-review-${CLAUDE_SESSION_ID}/prompt.txt | codex review -c 'sandbox_permissions=["disk-full-read-access"]' [options] -`
- **Gemini**: `cat /tmp/cross-review-${CLAUDE_SESSION_ID}/prompt.txt | gemini --approval-mode yolo [options]`

### CLI Error Handling

- **Timeout**: Skip that CLI, use the other's results only
- **Error output**: Include error details in report, continue with available results
- **All selected CLIs fail**: Report error and stop

## Step 4: Evaluate Feedback

Parse each CLI's output and classify each item by **severity** and **behavioral impact**.

### 4-1. Severity

| Severity | Priority |
|---|---|
| **must-fix** | High |
| **should-fix** | Medium |
| **suggestion** | Low |

### 4-2. Behavioral Impact

Classify each item as **behavioral** or **non-behavioral**.

**Behavioral** — changes that alter runtime behavior:
- Logic changes (conditions, control flow, algorithms)
- Function signatures or return values
- Error handling changes (adding/removing/changing catch, throw, error propagation)
- API contracts, data transformations, or observable side effects

**Non-behavioral** — changes with no runtime impact:
- Renaming (variables, functions — not affecting external API)
- Formatting, style, whitespace
- Comments, documentation
- Type annotation additions (no runtime effect)
- Dead code removal
- Import ordering

### 4-3. Tag and Filter

- Tag each item with source: `[codex]`, `[gemini]`, or `[both]` (when both CLIs raise the same point)
- Discard feedback that is vague, contradictory, or inapplicable to the reviewed content

## Step 5: Apply Fixes

**Skip this entire step if `--no-fix` is set.** Report only.

### 5-1. Decision Matrix

| Severity | Non-behavioral | Behavioral |
|---|---|---|
| **must-fix** | Auto-apply | Auto-apply |
| **should-fix** | Auto-apply | Ask user before applying |
| **suggestion** | Auto-apply | Ask user before applying |

### 5-2. Apply Procedure

**Global rule**: All ask-user items, across every severity tier, are deferred into a single combined batch presented at the end of Step 5 (one round-trip total, not one per tier). Step 6 (report) only begins after every ask-user item has resolved to a terminal state.

Within that constraint, work auto-apply items in severity order (must-fix → should-fix → suggestion) so highest-impact fixes land first. When you reach the end-of-Step-5 ask-user batch, order the items inside the batch by severity (must-fix → should-fix → suggestion), and within the same severity by their original index from Step 4 — so the user sees the highest-impact decisions first.

1. **Auto-apply items**: Apply the fix, verify syntax/lint if applicable. Terminal status: `applied`.
2. **Ask-user batch** (presented after all auto-applies, all tiers combined): Present each item with its severity, location, description, and the proposed change. Wait for explicit per-item approval. Terminal status: `applied` (approved) or `skipped (user declined)`.
3. **Skip conditions** (any severity): Skip with terminal status `skipped (<reason>)` only when the fix cannot be applied due to one of these objective preconditions:
   - location cannot be determined from the feedback (no resolvable file:line)
   - target file is outside the reviewed scope (see Scope rule below)
   - the proposed change conflicts with an already-applied fix from this run
   Other forms of "unsafe" (e.g., subjective doubt about correctness) are NOT skip conditions — for must-fix those are auto-applied per matrix; for should-fix / suggestion they fall under ask-user.

The Applied Fixes table reports only terminal statuses: `applied` / `skipped (<reason>)` / `skipped (user declined)`. No "pending" rows.

**Scope**: Only modify files included in the review target. For diff targets, limit to files in the diff. For file/glob targets, limit to the specified files. Skip any fix that would touch files outside the reviewed scope.

## Step 6: Output Report

Format:

```markdown
## Cross-Review Report

- **Date**: YYYY-MM-DD
- **Target**: [description of what was reviewed]
- **Focus**: [focus type]
- **Reviewed by**: [CLI names used]

### must-fix
| # | Source | Where | What | Why | How to fix |
|---|--------|-------|------|-----|------------|
| 1 | [codex] | file:line | issue | reason | recommendation |

### should-fix
| # | Source | Where | What | Why | How to fix |
|---|--------|-------|------|-----|------------|
| 1 | [gemini] | file:line | issue | reason | recommendation |

### suggestion
| # | Source | Where | What | Why | How to fix |
|---|--------|-------|------|-----|------------|
| 1 | [both] | file:line | issue | reason | recommendation |

### Applied Fixes (omit when `--no-fix`)
| # | Severity | Impact | What | Status |
|---|----------|--------|------|--------|
| 1 | must-fix | behavioral | issue | applied / skipped (reason) / skipped (user declined) |

### Summary
[overall assessment]
```

If no issues found for a severity level, omit that section.

- `--output <path>`: `mkdir -p` parent directory, then write report to that path
- No `--output`: report inline to the user

After outputting the report, clean up: `rm -rf /tmp/cross-review-${CLAUDE_SESSION_ID}/`

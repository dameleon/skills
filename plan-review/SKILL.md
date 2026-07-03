---
name: plan-review
description: >
  Review implementation plans using external LLM CLIs (Codex, Gemini).
  Reads the latest plan from ~/.claude/plans/ and improves it based on cross-model feedback.
disable-model-invocation: true
argument-hint: "[plan-file-path] [--output path]"
---

Review and improve an implementation plan using external LLM CLIs.

## Step 1: Locate Plan File

Parse `$ARGUMENTS` for a plan file path and `--output <path>` option.

- If a plan file path is provided: use it
- If omitted: auto-detect with `ls -t ~/.claude/plans/*.md | head -1`
- If no plan file found: report error and stop

Read the plan file content.

## Step 2: External LLM Review

Check available CLIs:

```
which codex 2>/dev/null
which gemini 2>/dev/null
```

If neither is available: report error and stop.

### Build Review Prompt

1. Read `review-prompts.md` in this skill directory for the base template
2. Replace `[PLAN_CONTENT]` with `$(cat -- "<plan-file-path>")` — the shell expands this at invocation time. Quote the path to handle spaces/special characters safely.
3. The assembled prompt string is passed directly to each CLI as an argument (no temp files)

`$(cat ...)` is expanded by the host shell, so CLI sandboxes cannot block file access.

**Session file**: `/tmp/plan-review-sessions-${CLAUDE_SESSION_ID}.json`

### Initial review (no session file)

Run reviews in parallel for each available CLI (timeout: 300s):

- **Codex**: `codex exec "<assembled prompt with $(cat ...)>"`
- **Gemini**: `gemini -p "<assembled prompt with $(cat ...)>"`

Extract Codex session ID from stdout (`session id:` line). Save to session file:

```json
{
  "codex_session_id": "<extracted-uuid-or-null>",
  "gemini_used": true
}
```

### Re-review (session file exists)

Read the session file. Run reviews in parallel (timeout: 300s):

- **Codex**: `codex exec resume <SESSION_ID> "<assembled prompt with $(cat ...)>"`
- **Gemini**: `gemini --resume latest -p "<assembled prompt with $(cat ...)>"`

Update session file with any new Codex session ID. If resume fails: fall back to initial review command.

### CLI Error Handling

- **Timeout**: Skip that CLI, use the other's results only
- **Error output**: Include error details in report, continue with available results
- **Both fail**: Report error and stop

## Step 3: Evaluate and Apply Feedback

Categorize each feedback item by severity:

| Severity | Action |
|---|---|
| **must-fix** | Apply automatically |
| **should-fix** | Apply automatically |
| **suggestion** | Record in Review Notes only |

Discard feedback that is vague, contradictory, or inapplicable to the plan's context.

Append a `## Review Notes` section to the plan:

```markdown
## Review Notes

- **Date**: YYYY-MM-DD
- **Reviewed by**: [CLI names used]

### Applied
- [What was changed and why]

### Noted (suggestions)
- [Suggestions recorded but not applied]

### Rejected
- [What was rejected and why]
```

## Step 4: Output

- If `--output <path>` was specified: write to that path (`mkdir -p` parent directory first)
- Otherwise: overwrite the original plan file

Report the output path and a summary of changes to the user.

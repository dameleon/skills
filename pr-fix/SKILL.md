---
name: pr-fix
description: >
  Fix unresolved review comments on a GitHub PR in an isolated worktree. Creates a worktree
  on the PR's branch, fetches unresolved review threads, validates each comment's accuracy
  and scope, plans fixes, confirms the plan with the user, applies changes following project
  rules (CLAUDE.md), commits, pushes, resolves addressed threads, and cleans up the worktree.
  Use this skill when the user wants to address PR feedback, fix review comments, or says
  phrases like "PRのコメント対応して", "レビュー指摘を修正", "fix PR comments",
  "address review feedback".
disable-model-invocation: true
argument-hint: "[PR-number] [--no-resolve]"
---

# PR Fix

Address unresolved review comments on a GitHub PR in an isolated worktree: fetch, plan, confirm, fix, commit, push, resolve threads, and clean up.

## Options

- `--no-resolve`: Skip resolving review threads after fixing (default: resolve addressed threads)

## Step 1: Identify PR and Compute Worktree Path

Parse `$ARGUMENTS`:

- Extract PR number (if present), otherwise auto-detect
- Check for `--no-resolve` flag (default: resolve enabled)

Determine the target PR number:

1. If `$ARGUMENTS` contains a number, use it as the PR number
2. Otherwise, auto-detect from the current branch:
   ```
   gh pr view --json number --jq '.number'
   ```
3. If no PR is found: report error and stop

Retrieve basic PR info for context:

```
gh pr view <number> --json title,headRefName,baseRefName
```

Then compute paths used throughout the rest of the workflow:

```bash
MAIN_REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$MAIN_REPO_ROOT")
WORKTREE_PATH="$(dirname "$MAIN_REPO_ROOT")/${REPO_NAME}+<PR-number>"
```

Hold on to `MAIN_REPO_ROOT`, `WORKTREE_PATH`, and the PR's `headRefName` — Step 2 and Step 11 need them.

## Step 2: Setup Worktree

Create an isolated worktree on the PR's branch, then switch the session into it so every subsequent tool call (Read / Edit / Write / Bash) targets the worktree automatically.

1. **Refuse to overwrite existing state.** Check both triggers separately so the remediation message matches the actual state — do not delete or reuse silently. **Echo the variables** so the LLM driving this skill can read them from the single Bash call's stdout and branch on the values.
   ```bash
   PATH_EXISTS=0
   REGISTERED=0
   [ -e "$WORKTREE_PATH" ] && PATH_EXISTS=1
   git -C "$MAIN_REPO_ROOT" worktree list --porcelain | grep -qF "$WORKTREE_PATH" && REGISTERED=1
   echo "PATH_EXISTS=$PATH_EXISTS REGISTERED=$REGISTERED"
   ```
   - If `REGISTERED=1`: tell the user to run `git -C "$MAIN_REPO_ROOT" worktree remove "$WORKTREE_PATH"` (add `--force` if it refuses) and retry.
   - If `PATH_EXISTS=1` and `REGISTERED=0` (stale leftover directory): tell the user to remove it manually with `rm -rf "$WORKTREE_PATH"` and retry — `git worktree remove` will fail because git doesn't know about it.
   - If `PATH_EXISTS=0` and `REGISTERED=0`: proceed to substep 2.
   - In the two failure branches, emit the message and **stop the skill — do not issue any further tool calls**. A non-zero exit inside a single Bash invocation does not by itself halt the workflow; the LLM driving this skill must observe the branch and stop.
2. **Fetch the latest commits** for the PR branch:
   ```bash
   git -C "$MAIN_REPO_ROOT" fetch origin <headRefName>
   ```
3. **Create the worktree on `headRefName`** (commits and pushes from inside will land on the PR branch directly).

   **Project rule takes precedence over pr-fix's default.** Many repos wrap or replace `git worktree` to copy untracked dev files (`.env`, IDE config, etc.) into the new worktree, or to enforce a different tool. Bypassing the project rule typically leaves the new worktree unbootable.

   Before running any worktree command, check whether the project defines its own worktree creation procedure. Look in this order:

   1. `<MAIN_REPO_ROOT>/.claude/rules/worktree.md` (or any `.claude/rules/*.md` mentioning worktree)
   2. `<MAIN_REPO_ROOT>/CLAUDE.md` / `<MAIN_REPO_ROOT>/AGENTS.md` sections about worktree
   3. `<MAIN_REPO_ROOT>/.github/copilot-instructions.md` or other agent-facing docs

   If the project mandates a specific tool/command, **follow it**, and preserve pr-fix's path convention (`$WORKTREE_PATH = <parent>/<repo>+<PR#>`) when the tool supports custom paths. For example, [git-wt](https://github.com/k1LoW/git-wt) accepts `--basedir "$(dirname "$WORKTREE_PATH")"` and a worktree name argument.

   **Default (no project rule found)** — raw `git worktree`:

   ```bash
   if git -C "$MAIN_REPO_ROOT" show-ref --verify --quiet "refs/heads/<headRefName>"; then
     git -C "$MAIN_REPO_ROOT" worktree add "$WORKTREE_PATH" <headRefName>
   else
     git -C "$MAIN_REPO_ROOT" worktree add -b <headRefName> "$WORKTREE_PATH" "origin/<headRefName>"
   fi
   ```
4. **Switch the session into the worktree** using the `EnterWorktree` tool with `path` pointing at the newly-added worktree:
   ```
   EnterWorktree(path="$WORKTREE_PATH")
   ```
   After this call, the session's cwd is the worktree. Read/Edit/Write paths can be written relative to the worktree, and Bash runs there by default. (`EnterWorktree` accepts only existing worktrees registered in `git worktree list`, which is satisfied by step 3.)

If any of steps 1-4 fails, stop here — the main worktree has not been touched. Do not proceed to Step 3.

## Step 3: Fetch Unresolved Comments

Use the GraphQL API to get only unresolved review threads:

```bash
gh api graphql -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          startLine
          comments(first: 10) {
            nodes {
              body
              author { login }
              createdAt
            }
          }
        }
      }
    }
  }
}' -f owner='{owner}' -f repo='{repo}' -F number=<number>
```

Extract `{owner}` and `{repo}` from `gh repo view --json owner,name`.

Filter to threads where `isResolved == false`. If there are no unresolved threads: report "No unresolved comments", then proceed to Step 11 to clean up the worktree, and stop.

## Step 4: Validate and Analyze Comments

For each unresolved thread, read the target file (relative paths now resolve inside the worktree) and understand the context around the commented line. Before planning any fix, **verify and critically evaluate the review comment itself**:

1. **Accuracy check**: Is the reviewer's指摘 factually correct? Does the code actually have the problem the comment claims?
2. **Impact assessment**: Would applying the suggested change introduce regressions, break other logic, or conflict with the existing design?
3. **Scope check**: Is the suggestion within the scope of this PR, or does it request an unrelated refactor?
4. **Completeness**: Does the comment address the root cause, or only a surface symptom?

Classify each comment into one of:

- **Valid — fix**: The comment is correct and should be addressed
- **Valid — needs discussion**: The comment raises a real concern but the best fix is debatable
- **Questionable**: The comment may be incorrect or the suggested change could cause issues — flag for user review
- **Out of scope**: The suggestion is unrelated to this PR's purpose

## Step 5: Build Fix Plan

Based on the analysis, build a fix plan:

```markdown
## Fix Plan

### Comment 1: @author — file.ts:42 [Valid — fix]
> [comment body summary]

**Analysis**: [why the comment is valid / what the actual issue is]
**Planned fix**: [concrete description of what to change]

### Comment 2: @author — utils.ts:15 [Questionable]
> [comment body summary]

**Analysis**: [why applying this as-is may cause issues / what the reviewer may have missed]
**Recommendation**: [proposed alternative or flag for discussion]

...
```

Group related comments that touch the same file or feature — they may require a coordinated fix.

Consider these when planning:
- Read the project's CLAUDE.md (if it exists) inside the worktree to understand coding conventions
- If a comment is unclear or ambiguous, flag it in the plan as needing clarification
- If a comment requests a change that would conflict with project rules, note the conflict

## Step 6: Confirm with User

Present the fix plan and ask for confirmation. Each user response below has a precise meaning — interpret literally and do not auto-promote a Questionable / Out-of-scope entry into a fix just because the user said "approve all".

| Response | Meaning | Effect on Step 7 (edit) | Effect on Step 9 (resolve) |
|---|---|---|---|
| **Approve all** | "Apply every plan entry whose plan describes a concrete edit." | Edit applied to every `Valid — fix` entry. `Valid — needs discussion` / `Questionable` / `Out of scope` are still **skipped** (no edit) because their plan has no concrete fix — the user would need to override them explicitly. | Resolve every thread whose edit was applied. Non-edit categories remain unresolved. |
| **Approve selectively** | User names specific comments to apply. | Edit applied only to the named entries. | Resolve only the named, applied threads. |
| **Override classification: fix N as if Valid** | User explicitly directs you to fix an entry you classified as Questionable / Out of scope. | Apply the edit for that entry as instructed (with the user-supplied direction). | Resolve that thread if the edit applied cleanly. |
| **Request changes** | User wants the plan adjusted. | Adjust the plan, re-present, wait for a fresh response. | — |
| **Add context** | User supplies extra info. | Incorporate, re-present plan, wait for a fresh response. | — |

Wait for the user's response before proceeding. Do not apply any fixes without confirmation. If the user's response is ambiguous (e.g. "approve" with no scope), ask before editing.

## Step 7: Apply Fixes

For each plan entry the user approved in Step 6 **and whose plan has a concrete edit** (i.e. classified `Valid — fix`, or `Questionable`/`Out of scope` that the user explicitly overrode):

1. Read the target file (the session cwd is the worktree, so relative paths and absolute paths both target it)
2. Apply the change following project conventions (CLAUDE.md)
3. Verify the change is correct — check syntax, imports, consistency with surrounding code

Plan entries without a concrete edit (`Valid — needs discussion`, or `Questionable` / `Out of scope` not overridden) are **skipped here** — no Read / Edit / Write. They surface in the Step 10 report under "Skipped" with the reason.

Keep fixes scoped to what the review comment asks for. Do not refactor surrounding code or add unrelated improvements.

## Step 8: Commit and Push

After all fixes are applied:

1. **Commit** using `/incremental-commit` — invoked while the session is in the worktree, so it operates on the right tree
2. **Push** to the remote branch (lands directly on the PR's `headRefName`):
   ```
   git push
   ```
3. **Verify** the push succeeded and report the result

If commit or push fails, stop here. Do **not** advance to Step 11 — leave the worktree (and the session) intact so the user can inspect or recover changes.

## Step 9: Resolve Threads

Unless `--no-resolve` is specified, resolve the review threads that were successfully fixed.

For each fixed thread, use the GraphQL mutation with the thread `id` obtained in Step 3:

```bash
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: { threadId: $threadId }) {
    thread { isResolved }
  }
}' -f threadId='<thread-id>'
```

- Only resolve threads whose edit was actually applied in Step 7 (status = "Fixed"). This is the only criterion — a user saying "Approve all" does **not** convert a non-edit plan entry into a Fixed status.
- Do NOT resolve threads that were skipped for any reason (no concrete edit in plan, needs discussion, questionable, out of scope, edit failed, etc.)
- If a resolve call fails, log the error but continue with the remaining threads

## Step 10: Report

Summarize what was done:

```markdown
## PR Fix Summary

- **PR**: #<number> — <title>
- **Worktree**: <worktree-path>
- **Unresolved comments**: <total>
- **Fixed**: <count>
- **Resolved**: <count> (or "skipped — `--no-resolve`")
- **Skipped**: <count> (with reasons)

### Applied Fixes
| # | File | Comment | Status | Resolved |
|---|------|---------|--------|----------|
| 1 | file.ts:42 | [summary] | Fixed | Yes |
| 2 | utils.ts:15 | [summary] | Skipped — needs clarification | — |
```

## Step 11: Cleanup Worktree

Only run this step when **all** prior steps (Setup through Report) succeeded.

1. **Exit the worktree session.** `EnterWorktree(path=...)` was used, so `ExitWorktree` cannot remove the worktree itself — call it with `keep` to return the session to the original cwd:
   ```
   ExitWorktree(action="keep")
   ```
2. **Remove the worktree** with git, now that the session no longer holds it:
   ```bash
   git -C "$MAIN_REPO_ROOT" worktree remove "$WORKTREE_PATH"
   ```
3. On success, append `- **Worktree**: removed (<worktree-path>)` to the report.
4. If `worktree remove` fails (e.g. uncommitted state somehow remains), do **not** force-remove. Print the error and the worktree path, and tell the user to clean up manually with `git worktree remove --force <path>` once they've rescued any wanted changes.

**On failure paths** (Setup, Apply, Commit, Push, Resolve): do not run this step. The session stays in the worktree so the user can inspect; they can leave manually later with `ExitWorktree(action="keep")` and decide what to do with the worktree on disk. Include the worktree path in the failure report instead.

---
name: jj-commit
description: Commit and push changes using Jujutsu (jj) VCS. Use this skill whenever the user wants to commit or push in a repository that uses jj, or when they say "jj commit", "jj push", "jjで commit", "jjでpush". Also trigger when the user says "commit" or "push" and the repository has a `.jj/` directory — jj should be preferred over raw git in colocated repos. Handles change description, splitting, bookmark management, and jj git push workflows.
---

# jj Commit & Push

Commit and push changes using Jujutsu (jj) in colocated git repos. jj eliminates staging, tracks changes automatically, and provides safe history rewriting via the operation log.

## Prerequisites

Before starting, verify jj is available and the repo is initialized:

```
jj status
```

If jj is not initialized, run `jj git init` first (creates a colocated repo alongside `.git/`).

## 1. Assess changes

Run as **parallel** Bash calls:

- `jj status`
- `jj diff --stat`
- `jj log -r 'trunk()..@' --limit 10`

This shows the working-copy changes, their size, and all changes since diverging from trunk. In jj, the working copy IS the current change — there's no staging step.

## 2. Describe the current change

Write the description using the Write tool + `--stdin` pipe pattern:

1. **Write message**: use the Write tool to create a message file
   - Path: `tmp/JJ_MSG` if `tmp/` exists at project root, otherwise `/tmp/JJ_MSG`
   - The body should explain **why** the change was made and **what purpose** it serves — the diff already shows *what* changed, so focus on intent and motivation
   - Match the repo's existing commit style; fall back to conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
   - Include `Co-Authored-By` trailer when the change was AI-assisted
2. **Describe**: `cat <path> | jj describe --stdin`
   - The pipe pattern avoids Bash tool confirmation prompts that complex quoting triggers
3. **Cleanup**: `rm <path>`

## 3. Handle multiple unrelated changes

If the working copy contains unrelated changes that should be separate commits, use `jj split` with file paths to separate them non-interactively:

```
jj split <file1> <file2> -m "description for the first change"
```

This puts the specified files into the first change (with the given description) and leaves everything else in a new child change. Repeat for further splits if needed. Then describe the remaining change:

```
cat <path> | jj describe --stdin
```

If the split requires finer granularity (e.g., splitting hunks within a single file), tell the user to run it interactively:

> "Run `! jj split -i` to interactively select which hunks go into each change."

## 4. Start the next change

If the user will continue working after committing:

```
jj new
```

This creates a new empty change on top of the current one. The previous change is now "finished." Unlike git, there's no risk of forgetting to commit — the working copy is always a change.

## 5. Push

Determine the push strategy based on context:

### Simple push (auto-named bookmark)

For quick pushes or first-time PRs — jj auto-creates a bookmark named `push-<change-id-prefix>`:

```
jj git push --change <change-id>
```

### Named bookmark push

When a specific branch name is needed (e.g., existing PR, team convention):

```
jj bookmark set <bookmark-name> -r <change-id>
jj git push --bookmark <bookmark-name>
```

If the bookmark already exists and just needs to be moved forward:

```
jj bookmark move <bookmark-name> --to <change-id>
jj git push --bookmark <bookmark-name>
```

### Bookmark conflicts

If push fails with "Bookmark is conflicted" (happens when remote state diverges from local), resolve by fetching and re-setting:

```
jj git fetch --remote origin
jj bookmark set <bookmark-name> -r <change-id>
jj git push --bookmark <bookmark-name>
```

### Choosing a strategy

- Use `--change` when creating a new PR or pushing a one-off change
- Use named bookmarks when updating an existing PR or following branch naming conventions
- Check existing bookmarks with `jj bookmark list` before deciding
- If the change is on an existing git branch (visible in `jj log`), move that bookmark forward rather than creating a new one

## 6. Verify

Run as **parallel** Bash calls:

- `jj status`
- `jj log -r 'trunk()..@' --limit 10`

## Safety notes

- `jj op log` shows every operation — any mistake can be undone with `jj op restore <op-id>`
- `jj git push` uses force-with-lease semantics by default, so it won't silently overwrite remote changes
- Avoid `jj describe` without `--stdin` or `-m` — it opens an editor, which blocks in non-interactive Bash
- Avoid `jj split` without file paths or `-m` — it opens a diff editor interactively. Use `jj split <files> -m "msg"` for non-interactive use

## Example

Working copy has changes to `src/auth.ts` and `src/auth.test.ts`:

```
# Assess
jj status
jj diff --stat

# Write message file
# (via Write tool to /tmp/JJ_MSG):
feat(auth): add JWT token validation

Session tokens were stored as plain strings, making it impossible to
verify expiration or issuer. JWT provides tamper-proof claims checking
so downstream services can trust the token without a DB round-trip.

Co-Authored-By: Claude <noreply@anthropic.com>

# Describe and clean up
cat /tmp/JJ_MSG | jj describe --stdin
rm /tmp/JJ_MSG

# Start next change
jj new

# Push (auto-named bookmark)
jj git push --change @-
```

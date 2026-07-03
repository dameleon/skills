---
name: incremental-commit
description: Commit edited files in logical or physical groups. Use this skill whenever the user mentions committing, asks to split changes into multiple commits, or says phrases like "commit", "コミットして", "コミット", "分けてcommit", "細かくcommit", "区切りごとにcommit". Also trigger proactively after completing multi-file editing tasks when the user requests a commit — even a simple "commit this" should use this skill if there are multiple changed files that could be logically grouped.
---

# Incremental Commit

Commit changed files in logical groups with conventional commit messages.

## 1. Assess changes

Run as **parallel** Bash calls:

- `git status`
- `git diff --stat`
- `git log --oneline -5`

## 2. Group files

Choose a strategy based on the nature of changes:

- **Logical** (default): group by feature, purpose, or domain
- **Physical**: one commit per file — when changes are independent or user requests it
- **Hybrid**: core changes get own commit; minor changes batched

Commit foundational/core changes first, then dependent ones.

## 3. Commit each group

For each group:

1. **Stage**: `git add <file1> <file2> ...` — always specify files by name to avoid staging unintended files like `.env`
2. **Commit**: use a heredoc to pass the message:
   ```bash
   git commit -m "$(cat <<'EOF'
   <subject line>

   <body>

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```
   - Include `Co-Authored-By` trailer
   - Keep subject line under 72 characters
   - The body should explain **why** the change was made and **what purpose** it serves — the diff already shows *what* changed, so focus on intent and motivation
   - Match the repo's existing commit style; fall back to conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)

Run independent commands as parallel Bash calls, not chained with `&&` or `;` — parallel is faster and one failure won't block the rest.

## 4. Verify

Run as **parallel** Bash calls:

- `git status`
- `git log --oneline -N` (N = number of new commits)

## Example

Changed files: `src/auth.ts`, `src/auth.test.ts`, `README.md`, `package.json`

**Group 1**: `src/auth.ts`, `src/auth.test.ts`
```
feat(auth): add JWT token validation

Session tokens were stored as plain strings, making it impossible to
verify expiration or issuer. JWT provides tamper-proof claims checking
so downstream services can trust the token without a DB round-trip.

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Group 2**: `README.md`, `package.json`
```
chore: update docs and dependencies

Align README setup instructions with the new auth flow and bump
jsonwebtoken to the version that includes the CVE-2024-1234 fix.

Co-Authored-By: Claude <noreply@anthropic.com>
```

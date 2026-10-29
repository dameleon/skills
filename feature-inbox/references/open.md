# feature-inbox: open

Create the one inbox issue for a feature. Read this before running `open`.

## 1. Preflight

```bash
gh auth status
gh repo view --json nameWithOwner,hasIssuesEnabled,url
```

Both must succeed and `hasIssuesEnabled` must be `true`. Otherwise stop and report — a
fork or mirror with issues disabled cannot host an inbox, and the user may want the
upstream repo instead. Two failed tries on auth / network means hand back, not retry.

When project context names a different tracker (Step 0 of SKILL.md), follow
`trackers.md` for that tracker's create / search calls; the layout below still applies.

## 2. Make sure one does not already exist

```bash
gh issue list --label feature-inbox --state open --limit 50 --json number,title,url
```

Compare the `inbox: ` titles against the feature title (and the slug you intend to use).
A hit means: show it, do not create a second one, and continue with `post` / `triage`
against the hit. Several plausible hits mean ask. Only an empty match proceeds.

## 3. Fill the template

`templates/INBOX.md`, with:

- `feature:` — a kebab-case slug derived from the title (`notification-settings`). It is
  the search key for pointers and later `open` runs; keep it stable.
- `opened:` — today's date. `last-ids: Q=0 I=0 H=0`, `summarized-through:` empty.
- `## 概要` — three to eight lines from the conversation so far: what the feature is, the
  design doc or epic it belongs to (`関連: #N` / a URL), scope boundaries already agreed,
  known constraints. Do not paste the design in; link it.
- The summary region stays at its placeholders. The `## メモ` section stays as the
  template's one-line hint — it belongs to the humans.

Every `@handle` in the body must be backticked (a bare one notifies a real user), and the
body must stay well under GitHub's 65,536-character cap.

## 4. Create and label

```bash
gh label create feature-inbox --color 0e8a16 --description 'feature / epic inbox issue' 2>/dev/null || true
gh issue create --title 'inbox: <feature title>' --body-file <tmp> --label feature-inbox
```

The title is a human phrase (`inbox: 通知設定画面`), not the slug. `--label` on create fails
when the label does not exist, which is why the create-if-missing line comes first.
Capture the URL and number from the output.

`--parent <epic>` (sub-issue nesting) and `--type` exist on gh ≥ 2.7x, but use them only
when the user asks: nesting changes the epic's own sub-issue list, which is a visible
choice on an issue that is not the inbox's to restructure. The `関連: #N` line in 概要 is
the default link. Neither flag is ever a reason to fail the create.

## 5. Leave a pointer for the next session

The inbox is only useful if the next session (yours or another agent's) can find it
without being told. Propose this line for project context:

```
feature-inbox: <feature title> → #<N> — 未決・課題・引継ぎは /feature-inbox post で記録する
```

- If `CLAUDE.local.md` exists or `git check-ignore -q CLAUDE.local.md` succeeds, append
  the line there (local to this checkout, gitignored, trivially reversible) and say so.
- Otherwise show the line and name the two candidate homes: `CLAUDE.local.md` (private) or
  `.claude/rules/feature-inbox.md` (team-shared, committed). Placing a committed file is
  the user's call.

## 6. Report

```markdown
## feature-inbox — opened
- Inbox: #<N> <url>
- feature: <slug> / label: feature-inbox
- Pointer: 追記済み (CLAUDE.local.md) | 下記の行を <場所> に置いてください
- 次: 設計・進行の相談で出た未決事項は `/feature-inbox post` で入れる
```

# Reference: closing — tracker operations

Commands for the Step 5 external writes and the Step 3 duplicate search. Read the section
for the detected destination only.

Tool selection is fixed by the user's global rules, and a missing or unauthenticated tool is
**not** a reason to switch trackers — report it and let the user decide:

| Tracker | Tool | Note |
|---|---|---|
| GitHub | `gh` CLI (or the GitHub MCP) | |
| Jira | `jira` CLI | The Atlassian MCP is explicitly not used |
| Backlog | the Backlog MCP, or the `bee` CLI via the `using-bee` skill | Follow whichever the project's rules name |

Flag names differ across CLI versions. If a command errors on an unknown flag, check
`<cmd> --help` once rather than guessing a second variant.

## GitHub

Comment on the PR or an issue:

```bash
gh pr comment <PR> --body '<body>'
gh issue comment <N> --body '<body>'
```

Reply to a review thread (deferred findings — keeps the reason next to the code):

```bash
gh api repos/{owner}/{repo}/pulls/comments/<first-comment-databaseId>/replies -f body='<reason + where it now lives>'
```

Create an issue:

```bash
gh issue create --title '<title>' --body '<body>' [--label '<label>'] [--assignee @me]
```

Duplicate search before creating (scope to the repo, include closed to avoid re-filing
something already fixed):

```bash
gh issue list --search '<keywords>' --state all --limit 10
```

Cross-linking: mention the PR (`#<PR>`) in the new issue's body so the trail survives, and
reference the new issue number in the PR comment. Do **not** write `Closes #<issue>` in a
merged PR's comment — it does nothing there and misleads readers.

Labels: use only labels that exist (`gh label list`). A create call with an unknown label
fails outright.

## Jira

Comment:

```bash
jira issue comment add <KEY> '<body>'
```

Create (`--no-input` keeps it non-interactive; the project and issue type must be valid):

```bash
jira issue create -p <PROJECT> -t <Task|Bug> -s '<summary>' -b '<body>' --no-input
```

Duplicate search:

```bash
jira issue list -q 'project = <PROJECT> AND resolution = Unresolved AND text ~ "<keywords>"'
```

Link the new issue to the original when the tracker models the relation (`jira issue link
<INWARD> <OUTWARD> <link-type>`; `jira issue link --help` lists the types available in that
instance). Always put the PR URL in the body — a Jira issue with no code pointer is the
common failure.

Jira bodies render in the instance's markup, not GitHub Markdown. Keep formatting plain:
short paragraphs and `-` bullets survive everywhere.

## Backlog

Follow the `using-bee` skill (or the Backlog MCP if the project's rules name it) for the
concrete calls; the shape is the same as above:

1. Search for an existing issue with the same keywords, unresolved states included.
2. Comment on the driving issue, or create a new one with the PR URL in the body.
3. Report the resulting issue URL back to Step 7.

## Body templates

Keep the bodies short and factual — the reader is someone with no session context.

**Deferred fix / unfinished scope (new ticket):**

```markdown
## 背景
<PR #n / チケットKEY> の作業中に判断した見送り事項。

## 内容
<what is not done, in one or two sentences>

## 見送った理由
<scope, risk, or dependency — the actual reason>

## 参考
- PR: <url>
- 該当箇所: <file:line>
```

**Existing bug found along the way (new ticket):**

```markdown
## 症状
<observed behavior>

## 再現手順
1. <step>

## 期待する挙動
<expected>

## 補足
<PR #n> の作業中に発見。今回の変更とは無関係で、修正は含まれていない。
- 該当箇所: <file:line>
```

**Closing comment on the PR or driving ticket:**

```markdown
今回の作業を締めました。

- 完了: <what shipped>
- 見送り: <item> → <issue url>
- 発見した別課題: <item> → <issue url>
- 前提・注意: <temporary workaround, assumption, or none>
```

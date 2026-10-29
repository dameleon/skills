# feature-inbox: trackers

GitHub is the default and the only tracker with concrete commands in the other reference
files. When project context (`CLAUDE.local.md` → `.claude/rules/*.md` → `CLAUDE.md`) names
another tracker, use the mapping below; the layout (owned summary region, typed entries,
IDs, one comment per post) is the same.

A missing or unauthenticated CLI is **not** a reason to switch trackers — report it and let
the user decide. Flag names differ across CLI versions; on an unknown-flag error check
`<cmd> --help` once rather than guessing a second variant.

| Operation | GitHub (`gh`) | Jira (`jira` CLI) | Backlog (`using-bee` skill / Backlog MCP) |
|---|---|---|---|
| Preflight | `gh auth status` | `jira me` | per `using-bee` |
| Find the inbox | `gh issue list --label feature-inbox --state open --search '<words>'` | `jira issue list -q 'project = <P> AND labels = feature-inbox AND summary ~ "inbox:"'` | search issues with keyword `inbox:` in the project |
| Create | `gh issue create --title 'inbox: …' --body-file f --label feature-inbox` | `jira issue create -p <P> -t Task -s 'inbox: …' -b "$(cat f)" -l feature-inbox --no-input` | create issue, summary `inbox: …` |
| Read body | `gh issue view N --json body --jq .body` | `jira issue view KEY --raw` → `.fields.description` | get issue → description |
| Write body | `gh issue edit N --body-file f` | `jira issue edit KEY -b "$(cat f)" --no-input` | update issue description |
| Read comments | `gh issue view N --json comments`; `gh api --paginate …/issues/N/comments` past 100 | `jira issue view KEY --comments 1000` | list comments (paginate) |
| Post comment | `gh issue comment N --body-file f` | `jira issue comment add KEY "$(cat f)"` | add comment |

Notes per tracker:

- **GitHub** — labels must pre-exist (`gh label create … || true` first). Bare `@handle`
  notifies; backtick every handle. Body cap 65,536 characters. Issues cannot be deleted
  via the API; the skill never closes one anyway.
- **Jira** — descriptions render in Jira markup, not GitHub Markdown. The HTML-comment
  markers are invisible in both, so the owned-region mechanism still works, but keep
  headings as `h2.`-free plain lines or accept that `##` shows literally; `-` bullets and
  blank-line paragraphs survive everywhere. Prefer an Epic as the inbox when the project
  already models the feature as one, and say so in the report.
- **Backlog** — follow `using-bee` for the concrete calls. Markdown vs Backlog notation is
  a per-space setting; check which one the space uses before writing the body.

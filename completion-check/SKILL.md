---
name: completion-check
description: >
  Independently verify whether a task's acceptance criteria are actually met
  by inspecting the codebase as a bias-free verifier — does NOT read the
  implementer's self-report, commit messages, or PR body claims.
  Use this whenever the user asks "本当に完了してる?" / "完了した?" /
  "完了確認して" / "acceptance check" / "acceptance verify" /
  "受入条件満たしてる?" / "done check" / "ちゃんと実装できてる?",
  or before creating a PR / closing an issue / merging when you need an
  independent gate on acceptance fit. Outputs per-criterion
  OK / NG / partial / unverifiable verdicts with `file:line` evidence,
  plus concrete fix suggestions for every gap. This is NOT a general
  code-quality, architecture, security, or design review — use
  `cross-review` or `code-review` for those. Scope is
  strictly "does the implementation satisfy the original instruction?".
argument-hint: "[issue-number | pr-number | acceptance-criteria-text] [--base ref]"
---

A bias-free verifier that judges whether the current codebase state actually satisfies the **original acceptance criteria** — independently of any self-report from the implementing agent.

The goal is to surface the **claim-vs-reality gap**: things an implementer (or future-you) might *believe* are done but that an outside reader cannot confirm from the code alone.

## Core Principle: Bias-Free Verification

> The verifier is only trustworthy if it cannot be persuaded by the implementer. The implementer's narrative — "I added tests", "I handled the error path", "this is done" — is exactly the input that biases a self-evaluation. So we exclude it on purpose, not by accident.

**You may read:**

- The original instruction / acceptance criteria (raw user request, issue body, plan document)
- The current codebase state via `git diff`, `git ls-files`, and direct file reads at `HEAD`
- Objective execution results (test runs, lint, typecheck, CI status) when needed to verify a criterion

**You must NOT read or rely on:**

- The implementing agent's self-report, thinking trace, or any "I did X" narrative
- Commit messages or PR descriptions written by the implementer (titles are OK for navigation, but never treat the claim portion as evidence)
- Code comments that *describe intent* rather than encode behavior (e.g., `// validates input` is not evidence; the actual validation code is)

If you find yourself about to quote a commit message or PR body as the reason a criterion passes, stop — that is the self-report bias the skill exists to prevent. Re-derive the verdict from the code.

## Step 1: Resolve Input

Parse `$ARGUMENTS`. The first positional value selects the input mode:

| First token | Mode | How to fetch acceptance criteria |
|---|---|---|
| `^[0-9]+$` (bare number) | Issue or PR — try issue first | `gh issue view <N> --json title,body` → if 404, `gh pr view <N> --json title,body` |
| `issue#<N>` | Issue | `gh issue view <N> --json title,body` |
| `pr#<N>` | PR | `gh pr view <N> --json title,body,baseRefName` |
| URL containing `/issues/<N>` | Issue | `gh issue view <N> --repo <owner/repo> --json title,body` |
| URL containing `/pull/<N>` | PR | `gh pr view <N> --repo <owner/repo> --json title,body,baseRefName` |
| Anything else | Direct text | Treat the entire `$ARGUMENTS` as the acceptance criteria |
| (empty) | Inherit | Use the latest user instruction in the current conversation as the acceptance criteria |

Optional flag (order-independent): `--base <ref>` overrides the diff base (default rules below).

### Diff Base Resolution

| Mode | Default base |
|---|---|
| Issue / direct text / empty | `git merge-base HEAD origin/main` (fall back to `main` if `origin/main` is unavailable) |
| PR | `baseRefName` from `gh pr view` (e.g., `origin/<baseRefName>`) |
| Any mode with `--base <ref>` | That ref |

Compute the diff once and reuse: `git diff <base>...HEAD`.

> **Bias guard for PR mode**: when the input is a PR, fetch only `title` and `body`. Do NOT read PR comments, review threads, or commit messages — these often contain the implementer's self-report. The PR body's *requirements section* is acceptable acceptance-criteria source; the *summary / "what I did"* section is not. If the PR body mixes both, extract only the requirements portion.

## Step 2: Normalize Acceptance Criteria

Decompose the raw instruction into independently verifiable units. Each unit must be expressible as **verb + target + verification method**.

| Raw phrasing | Normalized (verb + target + verification method) |
|---|---|
| "テストを追加" | `add` + `test cases for the new behavior` + `a new or modified file under tests/ that exercises the new code path` |
| "エラーハンドリング" | `handle` + `exception paths of the affected function` + `every error-producing call site is wrapped in try/catch or returns a Result-typed value` |
| "API ドキュメント更新" | `update` + `API reference doc` + `a new entry for the endpoint in docs/api-reference.md` |
| "POST /users を追加" | `add` + `POST /users endpoint` + `a registered route handler in the routing layer responding to POST /users` |

Rules:

- One criterion per verifiable outcome. Use the **same-evidence test** to decide split vs merge: if two phrases would be verified by inspecting the same file:line range and would always pass/fail together, merge them into one criterion (e.g., "add `formatDate` returning YYYY-MM-DD" — function existence and format spec collapse to one criterion because both are read off the same function body). If a single sentence implies outcomes that land in different files or require independent evidence (e.g., "add endpoint and tests"), split into separate criteria.
- If the criterion has no objective verification method (e.g., "make it nicer", "improve performance"), mark it as **unverifiable** at this step and carry it through to the report — do not silently drop it.
- Number criteria stably (`1`, `2`, ...) so the final report can reference them.

## Step 3: Investigate the Codebase

For each normalized criterion, locate the verification target in the **current code at `HEAD`**:

1. Search the diff first (`git diff <base>...HEAD`) — most acceptance criteria touch only changed files.
2. If the criterion concerns absence ("removed", "no longer uses X") or untouched-but-required state ("README must contain X"), also search the working tree directly via `Read` / `Glob` / `Grep`.
3. For criteria that require execution evidence (tests pass, typecheck passes), prepare to run the relevant command in Step 4. Do **not** trust prior CI status from PR mode — re-run locally when feasible.

### Large Diff Strategy

If the diff is large (>500 changed lines, or >20 files), narrow per criterion instead of reading the whole diff:

1. For each criterion, derive a search anchor (filename pattern, symbol name, route path, etc.).
2. Use `git diff <base>...HEAD -- <pathspec>` or `Grep` to read only the relevant slice.
3. Record any criterion whose verification would require reading >200 unrelated lines as **unverifiable** with reason "diff too large to verify without anchor".

## Step 4: Judge Each Criterion

Produce one verdict per criterion. The verdict set is intentionally four-valued — collapsing to OK/NG hides the cases where the truth is "evidence is missing", not "implementation is wrong".

| Verdict | Meaning |
|---|---|
| **OK** | Objective evidence in the code at `HEAD` confirms the criterion is satisfied. |
| **NG** | Objective evidence shows the criterion is NOT satisfied (required element absent, or present but contradicts the criterion). |
| **partial** | Some sub-aspects are satisfied, others are not. Always paired with a breakdown of which aspect failed. |
| **unverifiable** | The criterion is not objectively checkable from the inputs available (vague phrasing, evidence outside the diff scope, execution required but blocked). Never use this as a way to avoid a hard call — use it only when reasonable inspection cannot reach a verdict. |

### Aggregating to an Overall Verdict

The `総合判定` line in the report is a single value derived from the per-criterion verdicts. Apply this precedence (top wins):

| Condition | Overall verdict |
|---|---|
| Any criterion is **NG** | `NG` |
| No NG, but any criterion is **partial** | `partial` |
| No NG / partial, mix of **OK** and **unverifiable** | `partial` (treat missing evidence as a gap, not a pass) |
| Every criterion is **unverifiable** | `unverifiable` |
| Every criterion is **OK** | `OK` |

This rule resolves the case where verification truly cannot proceed (all-unverifiable) without collapsing it to a misleading OK.

### Evidence Requirement

Every verdict — including OK — must cite at least one piece of evidence in `file_path:line_number` form (or `file_path:line_start-line_end` for ranges). Evidence may be:

- A line of code that implements the required behavior (for OK / partial)
- The absence of an expected file or symbol, named precisely so the reader can verify it themselves (for NG)
- A specific command output and its result (for execution-based criteria)

If you cannot produce concrete evidence, the verdict is **unverifiable**, not OK.

### Execution-Based Criteria

For criteria that require running something (tests, typecheck, lint), run the command and capture the result:

- If the project has a documented test/lint command (e.g., in `CLAUDE.md`, `package.json` scripts, `Makefile`), use it.
- Treat exit code 0 + matching output as OK, non-zero as NG with the failing output excerpt as evidence.
- If the command cannot be run (missing dependency, sandbox restriction), mark **unverifiable** with reason "execution required but unavailable: `<command>`".

## Step 5: Propose Fixes for Gaps

For every **NG** and **partial** verdict, write a concrete fix proposal stating *what to add or change*, not *why it matters* (the verdict already encodes the why). The proposal must be actionable in one sitting and reference a target location (`file_path` or `dir/`).

Skip **unverifiable** verdicts in the fix list, but note them in the report so the user can decide whether to refine the criterion or accept the gap.

## Output Format

Use this template verbatim. If a section is empty, render it with "(none)" rather than omitting it — the user should be able to scan the same structure every time.

````markdown
## 完了条件達成チェック結果

- **Date**: YYYY-MM-DD
- **Target**: <issue#N | pr#N | "direct instruction">
- **Base**: <ref used for diff>
- **総合判定**: <OK | NG | partial | unverifiable> (<n_ok>/<n_total> OK、<n_partial> partial、<n_ng> NG、<n_unverifiable> unverifiable) — apply the precedence table in Step 4

### 受入条件ごとの判定

| # | 条件 | 判定 | 根拠 |
|---|------|------|------|
| 1 | <normalized criterion> | OK | `path/to/file.ts:12-18` に該当実装あり |
| 2 | <normalized criterion> | NG | `tests/api/` 配下に新規テストファイルなし |
| 3 | <normalized criterion> | partial | `path/to/file.ts:60` で DB エラー未捕捉、他は OK |
| 4 | <normalized criterion> | unverifiable | 「使いやすく」が客観条件に分解不可 |

### 修正が必要な項目

- (2) `tests/api/users.test.ts` を新規追加し、`POST /users` の正常系・異常系ケースを含める
- (3) `path/to/file.ts:60` の DB 呼び出しを try/catch で囲み、エラー時に 500 を返す

### 検証不能 / 要追加情報

- (4) 「使いやすく」を客観条件に分解するため、ユーザーに具体ゴールを確認

### 総合所見

<1-3 文で全体所感。OK のときは "受入条件は全て満たされている" で十分。NG / partial のときはどのタイプの抜けが多いか (例: テスト不足、エラーハンドリング漏れ、ドキュメント未更新) を一言。>
````

### Worked Example

**Input** (acceptance criteria text):

> `POST /users` を追加。リクエスト body は zod でバリデーション。テストを追加。README に API リファレンスを追記。

**Output:**

```markdown
## 完了条件達成チェック結果

- **Date**: 2026-05-14
- **Target**: direct instruction
- **Base**: origin/main
- **総合判定**: NG (2/4 OK、1 partial、1 NG、0 unverifiable)

### 受入条件ごとの判定

| # | 条件 | 判定 | 根拠 |
|---|------|------|------|
| 1 | `POST /users` ルートを登録 | OK | `src/api/users.ts:12` で router.post 登録 |
| 2 | body の zod バリデーション | OK | `src/api/users.ts:25-40` に zod schema と parse 呼び出し |
| 3 | テスト追加 | NG | `tests/api/users.test.ts` 等の新規テストファイルが diff に存在しない |
| 4 | README に API リファレンス追記 | partial | `README.md:120` に概要記載あり、ただし request/response 例なし |

### 修正が必要な項目

- (3) `tests/api/users.test.ts` を追加し、正常系 + zod バリデーション失敗系の 2 ケース以上を含める
- (4) `README.md` の `POST /users` セクションに request body / response の JSON 例を追記

### 検証不能 / 要追加情報

(none)

### 総合所見

実装本体とバリデーションは入っているが、テストとドキュメントの裏付けが不足。
```

## Relation to Other Skills

The verifier scope is narrow on purpose — overlap with neighboring skills would dilute the bias-free guarantee.

| Skill | Their scope | What `completion-check` does NOT do that they do |
|---|---|---|
| `cross-review` / `code-review` / `copilot-review` | General code quality, architecture, security, performance | Style critique, refactor suggestions, security audits — even if the code is ugly, if it satisfies the criterion the verdict is OK |
| `fix-issue` | Apply fixes for review feedback or issues | `completion-check` only reports gaps + proposed fixes; it does not edit files |

If the user asks for "review", default to `cross-review` / `code-review`. Use `completion-check` only when the question is specifically about acceptance fit ("did we actually complete the task?").

## Fallback Behavior

- **Ambiguous instruction with no decomposable criteria**: Return one `unverifiable` criterion per distinct vague phrase (splitting per the Step 2 same-evidence test — "使いやすく" and "パフォーマンスを改善" are two criteria, not one), each with an explanation, plus a question prompting the user to provide concrete acceptance criteria. Do not fabricate criteria.
- **Empty diff** (`git diff <base>...HEAD` shows nothing): If acceptance criteria are non-empty, every criterion is NG with evidence "no changes between `<base>` and `HEAD`".
- **Detached / no git history**: Treat the entire working tree at `HEAD` as the verification target; mention this in the "総合所見" section so the user knows the diff scope was unusual.

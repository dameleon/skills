---
name: plan-refinement
description: >
  Claude Code 標準 planner が出したプランを、後段で 5 軸 (具体性 / OPEN マーカー化 /
  検証手段付与 / 順序整合性 / 境界明示) に沿って機械的に書き直し、
  実装段 (executor) の再現性向上と仮定数低減を狙う精緻化 skill。
  Claude Code 標準 planner を置き換えるのではなく、その出力を尊重したまま
  後段で動くため、planner 自体の妥当性は判断しない。
  ExitPlanMode 直後、`/plan-refine` の明示呼び出し、または「プランを精緻化」
  「plan refine」「プランを refine」「指示として弱い」「実装段が迷いそう」
  などの語が出たときに発火する。元プランの 1.5 倍を超えない過剰詳細化ガード付き。
  効果測定は本 skill では行わない (planner-eval skill (#10) とワンセット)。
argument-hint: "[plan-text-or-empty]"
---

# Plan Refinement

Claude Code 標準 planner の出力を、**限定された 5 軸** に沿って機械的に書き直し、実装段の **再現性** と **仮定数低減** を狙う後段 skill。

planner 自体は置き換えない。標準 planner の意図と構造を保持したまま、機械的に検出できる弱点だけを潰す。

## 設計原則

### 1. 標準 planner の出力を尊重する

- 大幅な書き換えはしない。**機械的に検出できる弱点だけ** を修正する。
- 元プランの意図・構造を保持する。
- 過剰詳細化を抑える具体ルールは「過剰詳細化ガード」節 (下記) に一元化する。本節からは概念のみを示す。

### 2. refine 軸を限定する (5 criteria)

5 軸を超える「もっと良くする」は対象外。planner 自体の改善になり、置き換え路線に近づくため。

| # | 軸 | やること | 検出シグナル |
|---|---|---|---|
| 1 | **具体性** | 抽象名詞を具体識別子に置換 (file path, function name, route, env var 等)。文脈から確定不能なら **バックティック付き山かっこ kebab-case** で placeholder を残し (例: `` `<helper-name>` ``, `` `<test-file>` ``, `` `<expected-value>` ``)、同名を `## OPEN` に列挙する | "the helper" / "the file" / "the function" / "適切な" / "関連する" などの指示語・抽象名詞 (**illustrative list; semantic match 可** — 上記語と意味的に同型なら検出対象) |
| 2 | **OPEN マーカー化** | planner が決め切れていない点を末尾 `## OPEN` セクションに集約 | "場合によっては" / "もしくは" / "TBD" / "要相談" / "?" 終わりの文 / 2 つの選択肢を併記して片方を選んでいない |
| 3 | **検証手段の付与** | 各 step に "How to verify" を 1 行付ける | step に動詞 (add/update/replace/move) はあるが、完了をどう確認するかが書かれていない |
| 4 | **順序整合性** | step 内で定義前の概念に依存している箇所を検出し、依存順に並べ替える | step N で導入された識別子が step N-1 で参照されている / 「先に X を作る」という記述が後ろの step にある |
| 5 | **境界明示** | プラン冒頭に in-scope / out-of-scope の短い宣言を追加 | プラン全体に対象範囲の明示が無い / out-of-scope の言及が無い |

**残す優先度** (過剰詳細化ガード違反時の縮退に使う): **1 > 4 > 3 > 2 > 5**。具体性と順序整合性は実装段の再現性に直結するため最優先。境界明示は元プランが十分明確なら省略可。縮退の具体手順は「過剰詳細化ガード」節を参照。

## 過剰詳細化ガード (1 箇所定義の正本)

ガードに関わる全ルールは本節に集約する。他節からは本節を参照するのみ。

(a) **計測単位**: refined plan 本文の **行数** (markdown 上で「中身のある行」、空行と区切り `---` を除く)。文字数ではなく行数に固定する (実装間の解釈ぶれを排除するため)。`### Changes from original` 以降の自己申告セクションは行数カウントの対象外 (refined plan 本体のみが対象)。

(b) **閾値**: `refined 本文の行数 / 元プラン本文の行数 ≤ 1.5`。

(c) **短プラン緩和の例外**: 元プラン本文が **6 行以下** のときは、本ガードを無効化する。短い元プランは絶対値が小さく、ガードを掛けると軸 1 (具体性) や 4 (順序整合性) を諦めざるを得なくなり、実装段の利益を失うため。緩和を適用した場合は Skipped criteria に `over-expand guard: short-plan exception applied (元 N 行)` を 1 行記録する。

(d) **ガード違反時の縮退順序**: 軸を **`5 → 2 → 3 → 4 → 1` の順で 1 軸ずつ諦めて再生成** する (= 「残す優先度 1 > 4 > 3 > 2 > 5」の逆)。1 軸落とすたびに (b) を再判定し、収まったら停止。全軸 (5,2,3,4) を落としても収まらない場合は最終手段として **元プランをそのまま返し、Skipped criteria に `irreducible: returning original plan` と記録する** (refine 不可と判断)。

(e) **諦めた軸の記録**: 縮退で諦めた軸はすべて `### Skipped criteria` セクションに `<軸名>: <諦めた理由>` の形で記録する。記録漏れは出力フォーマット違反扱い。

### 3. 強制ではなく協調

- CLAUDE.md の指示経由で呼ばれる前提 (強制 hook ではない)。
- 「ExitPlanMode 直後に `/plan-refine` を呼ぶ」と user-scope CLAUDE.md に記載する運用。組み込み文例は後述「CLAUDE.md への組み込み」節を参照。
- ユーザー直接呼び出しも可 (`/plan-refine`)。

### 4. trivial タスクでは skip

元プランが以下の **いずれか (OR)** に該当する場合は refine を skip し、「refine は不要」とだけ返す:

- **T1**: 元プランの step 数が 1 以下
- **T2**: 元プランが in-scope / out-of-scope / "How to verify" の **3 要素を全て** (AND) 持っている
- **T3**: 以下を **両方** (AND) 満たす
  - 元プランが識別子 (バックティック付き) を 5 個以上含む
  - 抽象名詞が 1 つも検出されない (= 軸 1「具体性」の **検出シグナル列に挙げた語** のいずれも本文に出現しない)

ショートサーキットの理由を 1 行添える (例: `T1: step 数 1` / `T2: scope+verify 揃い` / `T3: identifier 5 個 + 抽象名詞なし`)。複数該当する場合は最初に満たした条件を引用すれば十分。

## 入出力仕様

### 入力

- 標準 planner が出したプラン本文 (text)。`$ARGUMENTS` で渡すか、空のときは直前メッセージの ExitPlanMode 内容を自動取得。
- 直前メッセージが planner 出力でない (= ExitPlanMode 直後でない) 場合は、ユーザーにプラン本文を貼ってもらうよう促す。

### 出力

````markdown
## Refined Plan

### Scope
- in-scope: ...
- out-of-scope: ...

### Steps

1. ...
   - How to verify: ...
2. ...
   - How to verify: ...

### OPEN
- ...

---

### Changes from original

| 軸 | 変更内容 |
|---|---|
| 具体性 | "helper" → `formatDate` (3 箇所) |
| 順序 | step 2 と 3 を入れ替え (step 3 が step 2 の出力に依存) |
| 検証手段 | 5 step 中 4 step に追加 |
| OPEN | 「API レスポンス形式」を OPEN に移動 |
| 境界 | 「DB スキーマ変更は別 PR」を out-of-scope に明記 |

### Skipped criteria
- (省略した軸があれば 1 行で理由を書く。なければ "(none)")
````

### 各セクションのメタ仕様

出力フォーマットを構成するセクションの必須性 / 順序 / 空時表記:

| セクション | 必須/任意 | 順序 | 空時の表記 |
|---|---|---|---|
| `## Refined Plan` | 必須 (trivial skip 時のみ省略) | 1 番目 | — |
| `### Scope` | 必須 | Refined Plan 直下 | in-scope / out-of-scope いずれかが空なら `- (none)` |
| `### Steps` | 必須 | Scope の次 | — (step 0 は許容しない) |
| `### OPEN` | 条件付き必須 | Steps の次 | bullet が 0 件なら **セクションごと省略** (空 OPEN を残さない) |
| `---` 区切り | 必須 | OPEN の次 (OPEN を省略した場合は Steps の次) | — |
| `### Changes from original` | 必須 | 区切りの次 | 表行 0 は許容しない (5 軸全て発火しなかったケースは trivial skip のはず) |
| `### Skipped criteria` | 必須 | Changes の次 | `(none)` を 1 行記述 |

**軸発火 / セクション空時のクロス参照ルール**: あるセクションを Refined Plan に追加 (= refine 介入で書き加えた) 場合、対応する軸を発火扱いとし `Changes from original` 表に行を追加する。例: `### Scope` セクションを追加した時点で軸 5 (境界明示) は発火 (in-scope のみ明示で out-of-scope が `- (none)` でも、Scope セクション自体の追加が境界明示の行為に当たる)。空表記 (`- (none)`) はセクション内容の表記規約であって、軸発火の有無とは独立。

`Changes from original` セクションを必ず出す理由:

- ユーザーが「何が変わったか」を一目で確認できる
- planner-eval skill (#10) が「介入が何をしたか」を機械的に拾える (静的指標の入力)

## 処理ステップ

1. プランをパース (markdown 構造として読む)。step、`OPEN` セクション、識別子の存在をマップする。
2. 「trivial 判定」を実施。skip 条件に該当したらショートサーキット。
3. 5 軸それぞれで弱点を検出 (上表の「検出シグナル」を使う)。
4. 弱点を修正。各軸は独立に動かす。
5. **過剰詳細化ガード**: 「過剰詳細化ガード」節 (本ファイル冒頭部) の (a)–(e) に従って判定 + 縮退 + 記録を実施。
6. `Refined Plan` + `Changes from original` + `Skipped criteria` を出力。

## トリガー条件

- 明示呼び出し: `/plan-refine` (slash command)
- CLAUDE.md 指示経由: 「ExitPlanMode が呼ばれた後に `/plan-refine` を実行する」と書いておく運用 (組み込み文例参照)
- description ベース: 「プラン精緻化」「plan refine」「指示として弱い」「実装段が迷いそう」等の語に反応

## CLAUDE.md への組み込み

user-scope (`~/.claude/CLAUDE.md`) または project-scope (`<repo>/CLAUDE.md`) に以下を追記する。

```markdown
## Plan refinement

ExitPlanMode が呼ばれた直後に、必ず `/plan-refine` を実行してプランを 5 軸 (具体性 / OPEN マーカー化 / 検証手段付与 / 順序整合性 / 境界明示) で書き直す。trivial と判定された場合は skip して構わない。Refined Plan を採用してから実装段 (executor) に渡す。
```

注: project-scope に置く場合は、その project のメンバー全員が合意できる粒度に留めること (個人の習慣レベルなら user-scope が向く)。

## Before / After サンプル

### サンプル 1: API endpoint 追加タスク

**Before (標準 planner の出力):**

```markdown
1. ユーザー作成エンドポイントを追加する。
2. リクエスト body のバリデーションを実装。zod でやる。
3. テストを書く。
4. ドキュメントを更新する。
```

**After (refined):**

````markdown
## Refined Plan

### Scope
- in-scope: `POST /users` エンドポイント本体、`src/api/users.ts` への route 登録、`tests/api/users.test.ts` の追加、`docs/api-reference.md` の更新
- out-of-scope: DB スキーマ変更、認証ミドルウェア、レート制限

### Steps

1. `src/schemas/user.ts` に zod schema `createUserSchema` を追加 (email/password を含む)
   - How to verify: `src/schemas/user.ts` 内に `createUserSchema` がエクスポートされている
2. `src/api/users.ts` に `POST /users` ハンドラを追加し、step 1 の schema で body を parse
   - How to verify: `router.post('/users', ...)` が登録され、`createUserSchema.parse(req.body)` が呼ばれている
3. `tests/api/users.test.ts` を新規作成し、正常系 + zod 失敗系 (400) のケースを書く
   - How to verify: テストファイルが存在し、`describe('POST /users')` 配下に 2 ケース以上
4. `docs/api-reference.md` に `POST /users` セクションを追加 (request body / response の JSON 例を含む)
   - How to verify: docs 内に request/response 両方の例がある

### OPEN
- password の最小長要件 (要件書に明示なし、6 文字でいいか?)

---

### Changes from original

| 軸 | 変更内容 |
|---|---|
| 具体性 | "ユーザー作成エンドポイント" → `POST /users` / "テスト" → `tests/api/users.test.ts` / "ドキュメント" → `docs/api-reference.md` |
| 順序 | step 1 (schema 定義) を本体実装より前に出した (step 2 が step 1 に依存) |
| 検証手段 | 全 4 step に "How to verify" を追加 |
| OPEN | password 最小長を OPEN に分離 |
| 境界 | DB スキーマ変更・認証・レート制限を out-of-scope に明示 |

### Skipped criteria
- over-expand guard: short-plan exception applied (元 4 行)
````

5 軸すべてが発火した典型例。元プラン 4 行 → refined 本文 約 20 行。元プラン本文が 6 行以下のため「過剰詳細化ガード」節 (c) の短プラン緩和が適用され、1.5 倍ガード判定はスキップ (Skipped criteria に明示記録)。

## 既存 skill との関係

| skill | 関係 |
|---|---|
| `planner-eval` (#10) | **本 skill の効果検証装置。ワンセット。** 本 skill が出した `Changes from original` を機械的に拾い、ablation で再現性 / 仮定数を測る |
| `completion-check` (#9) | 別軸。実装 vs 受入条件の照合。本 skill はプラン段、completion-check は実装後 |
| `plan-review` | 別軸。プランの妥当性を質的にレビュー。本 skill は機械的書き直し |
| `code-review` / `cross-review` | 別軸。コード品質。本 skill はプラン段なのでスコープ外 |

「プランをレビューしたい」と言われたら `plan-review`、「プランを書き直したい / 精緻化したい」と言われたら本 skill。

## 効果測定

本 skill **自体では効果測定をしない**。効果は `planner-eval` skill (#10) が ablation で測る:

- 条件 `baseline` (refinement なし) vs `refinement` (本 skill を介入として適用)
- 動的指標: 再現性 / 仮定数 / golden 一致率 / 逸脱率
- 静的指標: 具体性スコア / 前方参照違反数 / 検証ステップ被覆 / OPEN マーカー数

不確実性の正直な開示: 効果は中規模タスクで 10–25% 改善が現実線という見積もり (根拠は弱い、ゆえに #10 とセット)。

## Fallback

- **入力が空 かつ 直前メッセージが planner 出力でない**: 「ExitPlanMode 直後に呼ぶか、プラン本文を `$ARGUMENTS` で渡してください」と返す。
- **元プランが markdown として parse できない (自由文 1 段落)**: 5 軸のうち最低限「具体性」と「検証手段付与」だけ適用し、step 構造化も試みる。Changes 表の「順序」は "適用不能 (元プランに順序構造なし)" と記す。
- **trivial 判定でショートサーキット**: 「refine は不要 (理由: ...)」と 1 行返して終了。Refined Plan セクションは出さない。

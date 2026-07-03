---
name: planner-eval
description: >
  Claude Code 標準 planner を baseline として固定し、plan 段に挟む各種介入
  (plan-refinement skill, 将来の静的解析 hook 等) の効果を ablation で
  empirical に測る framework。「どの介入が、どの metric を、どれだけ動かすか」を
  bias-free executor を用いた multi-run で客観データとして出す。
  planner 自体を differentially 評価する skill ではない (置き換え路線は捨てた)。
  使うとき: 介入 skill (例: plan-refinement) を作った/改訂した直後の効果検証、
  「介入の効き目を測りたい」「ablation で planner-eval したい」
  「plan-as-prompt の改善が効いてるか確かめたい」と言われたとき。
  軽量モード (静的指標のみ) と完全モード (executor まで回す) の 2 段階あり。
argument-hint: "[config-path] [--mode static|full]"
---

# Planner Eval

「作業指示 → プラン → 実装 → 完了確認 → レビュー」のうち、**プランの prompt 品質** に介入する手段 (plan-refinement skill 等) の効果を ablation で測る framework。

「何をやるべきか」(research 軸) は対象外。「どう伝えるか」(prompt 軸) のみ評価する。

## 設計原則

### 1. Claude Code 標準 planner を baseline として固定する

- planner 自体を differentially 評価しない。
- 比較するのは **「介入なし (baseline)」 vs 「介入あり (treatment)」** のみ。
- baseline は常に「Claude Code 標準 planner の出力をそのまま executor に渡す」。
- 理由: 標準 planner を上回る planner を自前で書く保証がない以上、置き換え路線では ROI が不確実。介入路線に限定することで「介入の効き目」だけを切り分けて測れる。

### 2. 介入を差し込み可能な抽象として扱う

config レベルで介入種類を選択可能にする。初期サポート:

| `intervention` 値 | 意味 |
|---|---|
| `none` | baseline。planner の出力をそのまま executor に渡す |
| `plan-refinement` | plan-refinement skill (#11) を planner の後段で呼ぶ |
| `static-check-hook` | (将来) 静的解析 hook を後段に挟む |
| `claude-md-guidance-only` | (将来) CLAUDE.md の指示のみで planner を誘導 |

新規介入は本 skill 側のコードを変えずに追加できる構造にする (config の `intervention` キーと、その介入をプランに適用するハンドラの 1:1 対応のみ)。

### 3. Bias-free executor

実装役 (executor) エージェントには次のみを渡す:

- **介入後の最終プラン** (= treatment 条件なら refine 済み、baseline 条件なら planner 生出力)
- リポジトリ状態 (read-only)

executor が受け取ってはいけないもの:

- **元の作業指示文** (executor が plan を bypass して指示を直接読むと、planner / 介入の質を測れない)
- **research artifact** (研究軸の情報。プラン段の評価では遮断する)
- **介入前のプラン** (差分を見せると bias が入る。「介入後がより良いと信じる」誘導になる)
- **介入処理の中身** (どの skill が動いたか / どの軸を refine したか。executor は「与えられたプランがどう作られたか」を知らずに実行する)

これを徹底することで、executor の出力差は「与えられたプラン本体の質」だけに帰属する。

### 4. multi-run による分散測定

各 (タスク × 条件) について executor を **N 回 (デフォルト 3 回)** 独立実行し、分散を計測する。

- 単発実行だと LLM の確率的揺れを介入効果と混同する。
- N=3 は最小実用ライン。タスクが少ない (3 件未満) なら N=5 に上げる。
- 再現性 (self-consistency) はそもそも multi-run でしか測れない (最重要指標)。

## 入出力仕様

### 入力 (config)

YAML を `$ARGUMENTS` で指定 (path)。スキーマ:

```yaml
tasks:
  - id: <stable identifier>           # 必須。レポートで参照する
    research_artifact: |              # 必須。planner に渡す指示文 (must-do を含む)
      must-do:
        - <要件 1>
        - <要件 2>
    golden_diff: <path to .diff>      # 任意。golden 一致率の比較対象
    timeout_sec: 600                  # 任意。executor 1 run のタイムアウト

conditions:
  - id: <stable identifier>           # 必須。レポートで参照する
    intervention: <none|plan-refinement|static-check-hook|...>
    intervention_args:                # 任意。介入に渡す追加パラメータ
      <key>: <value>

executor:
  agent: general-purpose              # 必須。bias-free に動かす subagent 種別
  runs_per_plan: 3                    # 必須。1 (plan, condition) あたりの繰り返し回数
  allow_tools: [Read, Grep, Glob, Bash, Edit, Write]  # 任意。executor に許す tool 集合

mode: static | full | static-from-plans  # 任意。CLI フラグでも上書き可。デフォルト full
report:
  output_path: <path>                 # 任意。デフォルトは ./planner-eval-report-<timestamp>.md
  bootstrap_iterations: 1000          # 任意。タスク間ブートストラップ CI の試行回数
```

#### モードの違い

| mode | planner 呼ぶ | 介入適用 | executor 走らせる | 入力契約の差 |
|---|---|---|---|---|
| `full` | ✓ | ✓ | ✓ | 標準 (上記スキーマ通り) |
| `static` | ✓ | ✓ | ✗ | 標準 (上記スキーマ通り)。静的指標のみ計算 |
| `static-from-plans` | ✗ | ✗ | ✗ | `tasks[].plans[]` を直接渡す (下記スキーマ参照)。既に得たプラン本文を比較したいケース用 |

#### `static-from-plans` モードの追加スキーマ

planner / 介入を実行せず、既に手元にあるプラン本文を直接静的指標で比較するモード。`conditions` は不要 (各 plan に `condition_id` を持たせる)。

```yaml
mode: static-from-plans

tasks:
  - id: add-user-endpoint
    plans:
      - condition_id: baseline
        plan_text: |
          1. ユーザー作成 API を追加する
          2. ...
      - condition_id: refinement
        plan_text: |
          ## Refined Plan
          ### Scope
          ...

# executor, conditions は本モードでは無視される (記述しても OK だが警告ログのみ出す)
```

この拡張により、Iter 1 で surface した「既に得たプラン本文を直接評価したい場合の入力契約が無い」問題を解消する。

### サンプル config

`examples/plan-refinement-ablation.yaml` に plan-refinement skill (#11) を対象とした **初期 user story** のサンプルを同梱している。次節を参照。

## アーキテクチャ

```
[task.research_artifact] ─► Claude Code planner ─► plan_raw
                                                      │
                                       ┌──────────────┴──────────────┐
                                       ▼                              ▼
                              [intervention=none]         [intervention=plan-refinement]
                                       │                              │
                                       ▼                              ▼
                                  plan_baseline                   plan_treated
                                       │                              │
                                       └──────────► executor ◄────────┘
                                                      × N runs
                                                      │
                                                      ▼
                                              dynamic metrics
                                                      │
                          ┌───────────────────────────┴───────────────────────────┐
                          ▼                                                        ▼
                  static metrics (plan 自体)                       条件間比較 + bootstrap CI
                          │                                                        │
                          └──────────────────────────►  report  ◄──────────────────┘
```

## 処理フロー

mode によって分岐する。

### `full` / `static` モード

1. **config 読み込み**: schema 検証。`tasks × conditions` のマトリクスを構築。
2. **plan 生成**: 各 task について Claude Code 標準 planner を 1 回呼び、`plan_raw` を取得。conditions 全てが同じ `plan_raw` を起点にすることで、planner の確率的揺れを条件間バイアスにしない。
3. **介入適用**: 条件ごとに `plan_raw` に介入を適用。`none` ならそのまま、`plan-refinement` なら skill を呼んで refined plan を得る。条件ごとに `plan_used` (executor に渡すプラン) と `intervention_log` (介入が何をしたか) を保存。
4. **静的指標算出**: `plan_used` 単体から計算 (executor を回さなくても出る)。後述「メトリクス」節。
5. **bias-free executor 実行**: 各 (task, condition) について N 回、`plan_used` のみを入力として executor を独立 dispatch。executor の出力 (diff, 発話ログ) を保存。
   - dispatch ごとに新しい subagent を立てる。同一 subagent を再利用すると前回の文脈で bias する。
   - mode が `static` の場合は本ステップを skip。
6. **動的指標算出**: 各 (task, condition, run) の executor 出力から計算。`static` モードでは skip。
7. **条件間比較**: 各指標について baseline vs treatment の差を出す。`full` ではタスク間ブートストラップで 95% CI を算出 (デフォルト 1000 iter)。`static` は単一観測のため CI なし point estimate のみ。
8. **レポート出力**: 後述「出力レポート例」のフォーマットで markdown を書き出す。`static` モードでは動的指標セクション全体を省略し、その旨を冒頭に注記。

### `static-from-plans` モード

1. **config 読み込み**: `tasks[].plans[]` を構造として検証 (各 task に最低 2 plan、各 plan に `condition_id` と `plan_text` が必須)。
2. **静的指標算出**: 各 `plan_text` に対し直接「メトリクス」節の静的指標 4 つを計算。planner / 介入は呼ばない。
3. **条件間比較 + レポート出力**: `static` モードと同じフォーマット。冒頭に「mode: static-from-plans (planner / 介入未実行)」と注記。

## メトリクス

### 静的指標 (プラン単体、executor 不要)

各指標の算出規則は「実装が違っても同じ数値になる」程度に具体化する。曖昧な定義は別実装間で再現性が無くなるため。

#### 1. 具体性スコア (0–1)

`識別子トークン数 / noun_total`。

- **識別子トークン抽出フロー** (順に判定。早期確定):
  1. **バックティック内の語句は無条件で identifier**。語句内に **outermost whitespace** (引用符 `'…'` / `"…"` / 丸かっこ `(…)` の **外側** にあるスペース) がある場合のみそこで分解し、各片を別 identifier として数える (occurrences ベース)。クォート / カッコ内のスペースでは分解しない。
     - 例: `` `POST /users` `` → outermost space で分解 → `POST` と `/users` の 2 識別子
     - 例: `` `describe('POST /users')` `` → outermost にスペース無し (スペースはシングルクォート内) → 全体で 1 識別子
     - 例: `` `createUserSchema.parse(req.body)` `` → 1 識別子
  2. バックティックの外で、次の (a)–(c) のいずれかに該当する語を identifier とする:
     - (a) ピリオド `.` / スラッシュ `/` / アンダースコア `_` のいずれかを含む長さ 3 以上の語 (例: `req.body`, `src/api/users.ts`, `snake_case`)
     - (b) 大文字小文字が混在する長さ 3 以上の語 (PascalCase / camelCase。例: `createUserSchema`, `HttpClient`)
  3. ステップ 2 の対象から **単一の全大文字 acronym** (`API`, `JSON`, `README`, `HTTP` 等) は除外し plain noun に回す。**この除外はバックティックの外でのみ適用** (ステップ 1 で identifier 化済みのトークンは acronym 形状でも identifier のまま、つまりステップ 1 が優先)。
- **plain content noun**: 次の規則で抽出:
  - (a) 英単語: 長さ 3 以上、stop-words を除外 (`the`, `a`, `an`, `is`, `to`, `of`, `and`, `or`, `in`, `for`, `with`, `on`, `at`, `by`, `as`, `it`, `be`, `do`, `if`, `that`, `this`, `from`, `into`)
  - (b) カタカナ: 連続 1 文字以上の Katakana run を 1 トークン
  - (c) 漢字: 連続 **2 文字以上** の Kanji run を 1 トークン (送り仮名のひらがなは含めない、Kanji run の境界で切る)。**長さ 1 の Kanji run は除外** (動詞語幹断片 — 例: 「書く」の `書`、「呼ばれている」の `呼` — が plain noun に混入して分母を膨らませるのを防ぐ)
  - **除外**: ひらがな単独 / 数字 / 記号 / 助詞
- **noun_total** = `識別子トークン数 + plain content noun 数`
- noun_total = 0 のとき (空プラン等) は具体性スコア = 0 と定義

#### 2. 前方参照違反数

- **「定義 step」**: 識別子の**最初の出現箇所**を含む step。`### Scope` ブロック (および冒頭の見出し節) は **step 0** として扱い、ここに現れた識別子は後段 step が参照しても違反としない。
- **edge 生成**: step i (i ≥ 1) に登場する識別子 X について、X の最初の出現が step j のとき edge `(i → j)` を貼る。
- **違反判定**: `j > i` のとき (= 後段で初出の識別子を前段が参照) を 1 違反とカウント。
- **重複の丸め**: 同じ (i, X) ペアは 1 違反として丸める (同一識別子の複数回参照を多重カウントしない)。
- **対象**: 識別子 (上記 1 の (a)–(c) を満たすもの) のみ。plain noun は対象外。

#### 3. 検証ステップ被覆 (0–1)

`How to verify 行を含む step 数 / 全 step 数`。

- **検索パターン** (大小文字不問): `How to verify` または `検証手段:` または `検証方法:` のいずれかを含む sub-bullet / 行を 1 つ以上持つ step を「カバーされている step」と判定。
- **分母**: numbered top-level step 数 (1., 2., ... の直下に書かれた step)。

#### 4. OPEN マーカー数 + 健全性タグ

単独の数値スコアではなく `raw count + tag` の組として報告する (OPEN の多寡は単調指標ではないため)。

- **raw count**: 末尾の `## OPEN` または `### OPEN` セクション直下の bullet (`-` または `*` で始まる行) の個数。該当セクション無しなら 0。
- **健全性タグ**:
  - `healthy`: count が 0–3 の範囲、または count = 0 かつ抽象名詞 (軸 1 検出シグナル相当) が plan 本文に残っていない
  - `many-unresolved`: count ≥ 4
  - `suspicious-zero`: count = 0 だが抽象名詞が plan 本文に残っている (OPEN 見逃し疑い)
- **比較**: 条件間比較は raw count 差分 + tag 変化の両方を提示する。

### 動的指標 (executor を走らせて測る、5 つ)

| # | 指標 | 算出方法 | 重要度 |
|---|---|---|---|
| 1 | **再現性 (self-consistency)** | 同 plan の N 回 run 間の diff 距離 (例: 行レベル Jaccard 距離の平均) を 1 から引いた値。低分散 = 高スコア | **最重要** |
| 2 | **仮定数** | executor 発話中の `"I will assume"` / `"I'll choose"` / `"仮定する"` / `"裁量で"` などのマーカー出現数 (run 平均) | 高 |
| 3 | **golden 一致率** | `golden_diff` が指定されているとき、実装 diff と golden の AST 類似度 (なければ行レベル類似度) | 中 |
| 4 | **逸脱率** | プランで決定済みの識別子 / 選択を、実装が違えた割合。`plan_used` から識別子集合を抽出し、実装 diff の対応箇所と突き合わせる | 中 |
| 5 | **OPEN 整合性** | プランの `## OPEN` 項目と executor の escalation 点 (発話中の `"確認したい"` / `"質問"` マーカー) の集合一致率 (Jaccard) | 低 |

再現性が最重要なのは、「同じプランから同じ実装が出る」=「プランが指示として効いている」の最も直接的な証拠だから。golden 一致率は golden_diff が無いと出せないため任意。

## 出力レポート例

````markdown
## planner-eval result

- **Date**: 2026-05-14
- **Mode**: full
- **Tasks**: 3 件
- **Conditions**: baseline, refinement
- **Runs per (task, condition)**: 3

### 条件別サマリ (全タスク平均)

| condition | 再現性 | 仮定数 | golden 一致 | 逸脱率 | 静的具体性 |
|---|---|---|---|---|---|
| baseline | 0.42 | 4.3 | 0.51 | 0.28 | 0.31 |
| refinement | 0.71 | 1.8 | 0.78 | 0.12 | 0.62 |

### 介入効果 (treatment − baseline)

- 再現性: +0.29 (95% CI: +0.18, +0.40) ★ 有意
- 仮定数: −2.5 (95% CI: −3.4, −1.6) ★ 有意
- golden 一致: +0.27 (95% CI: +0.12, +0.41) ★ 有意
- 逸脱率: −0.16 (95% CI: −0.24, −0.08) ★ 有意
- 静的具体性: +0.31 (95% CI: +0.22, +0.40) ★ 有意

### タスク別詳細

| task | condition | run | 再現性 | 仮定数 | golden 一致 |
|---|---|---|---|---|---|
| add-user-endpoint | baseline | 1 | — | 5 | 0.48 |
| add-user-endpoint | baseline | 2 | — | 4 | 0.55 |
| add-user-endpoint | baseline | 3 | — | 4 | 0.50 |
| add-user-endpoint | baseline | (集計) | 0.40 | 4.3 | 0.51 |
| add-user-endpoint | refinement | 1 | — | 2 | 0.79 |
| add-user-endpoint | refinement | 2 | — | 2 | 0.76 |
| add-user-endpoint | refinement | 3 | — | 1 | 0.80 |
| add-user-endpoint | refinement | (集計) | 0.73 | 1.7 | 0.78 |
| ... | ... | ... | ... | ... | ... |

### 介入ログ (Changes from original の集計)

- plan-refinement が触った軸の頻度 (タスク × 条件全体):
  - 具体性: 3/3 タスクで発火 (識別子置換 平均 4.7 箇所/タスク)
  - 順序整合性: 1/3 タスクで発火
  - 検証手段付与: 3/3 タスクで発火 (step あたり平均 0.8 行追加)
  - OPEN マーカー化: 2/3 タスクで発火
  - 境界明示: 3/3 タスクで発火

### 所見

再現性と仮定数が両方とも有意に改善している。介入ログを見る限り「具体性」「検証手段」「境界明示」の 3 軸が常時発火しており、これらが指標改善の主因と推定。順序整合性は 1/3 タスクしか発火しておらず、効果寄与は限定的の可能性。
````

## 軽量モード (mode: static / static-from-plans)

executor を回さず、静的指標のみで条件間比較する。

- **`static`**: planner と介入は走らせるが executor を skip。介入実装のイテレーション初期、頻繁に回したいときの主用途。
- **`static-from-plans`**: planner と介入も走らせず、既存プラン本文を直接比較。プラン段の改善を手元で先に実験するときや、再現実験で同じプランを使い回したいときの用途。
- 利点: 数秒〜数十秒で完結。multi-run 不要。
- 制約: 再現性 / 仮定数 / golden 一致率 / 逸脱率 / OPEN 整合性は出ない (動的指標は full モード専用)。
- 推奨運用: 軽量モード (static または static-from-plans) で「静的指標が動くこと」を確認 → 完全モードで動的指標を取りに行く、の 2 段階。

## #11 (plan-refinement) ablation サンプル config

`examples/plan-refinement-ablation.yaml` を参照。最初の user story として、本 skill のリリース時点で plan-refinement skill の効果を測るための最小構成を同梱している。

```yaml
tasks:
  - id: add-user-endpoint
    research_artifact: |
      must-do:
        - POST /users endpoint を新規追加
        - body は email/password の zod schema で検証
        - 失敗時 400, 成功時 201
        - 新規テストを tests/api/users.test.ts に追加

conditions:
  - id: baseline
    intervention: none
  - id: refinement
    intervention: plan-refinement

executor:
  agent: general-purpose
  runs_per_plan: 3
  allow_tools: [Read, Grep, Glob, Bash, Edit, Write]

mode: full
```

タスクを増やしたいときは `tasks` 配列に追加するだけ。golden_diff があれば `golden_diff` キーを足すと golden 一致率も出る。

## 既存 skill との関係

| skill | 関係 |
|---|---|
| `plan-refinement` (#11) | **本 skill の初期 user story。ワンセット。** 本 skill が「介入の効き目を測る装置」、`plan-refinement` が「測られる側の最初の介入」 |
| `empirical-prompt-tuning` | 上位思想 (両面評価のメタスキル)。本 skill はその開発ワークフロー特化版 (プラン段に限定し、ablation で介入を切り分ける) |
| `completion-check` (#9) | 動的指標の一部として将来統合できる候補。現状は「逸脱率」「golden 一致率」が近い役割を担うが、完了条件ベースの判定ロジックは completion-check の方が成熟している |
| `cross-review` / `codex-review` / `copilot-review` | 別軸。コード品質レビュー。本 skill は「指示としてのプランの効き目」が対象 |
| `plan-review` | 別軸。プランの妥当性を質的にレビュー。本 skill は実装段への効果を empirical に測る |

「プランをレビューしたい」と言われたら `plan-review`、「介入の効き目を測りたい」と言われたら本 skill。

## スコープ外

- **介入自体の実装**: 各介入は別 skill (例: `plan-refinement` skill) または別 issue で扱う。本 skill は「介入を差し込む枠」と「効果を測る指標」のみを提供する。
- **research artifact の自動抽出**: まずは手書きで OK。issue 本文や PR 説明から must-do を抽出する自動化は将来課題。
- **CI 組み込み**: ablation 結果を CI に乗せる pipeline 化は将来課題。

## Fallback

- **config に conditions が 1 件しかない**: ablation できないため明示的にエラーで停止。最低 `baseline` + 1 treatment が必要。
- **planner が同じ task に対して run ごとに違うプランを出す (確率的揺れが大きい)**: `plan_raw` を 1 回だけサンプルする現仕様では条件間バイアスは出ないが、絶対値が揺れる。安定化したい場合は config に `plan_seed` などを足すか、`plan_raw` を複数回サンプルして条件間で交差させる拡張が将来必要 (現状は OPEN)。
- **executor が timeout する run**: その run は集計から除外し、レポートに「除外 run 数」を明記。除外が runs_per_plan の半数を超えた条件は集計信頼性が低いため警告マークを付ける。
- **golden_diff が指定されていない task**: 「golden 一致率」「逸脱率」の一部を unverifiable として落とし、集計から除外。レポートには「golden_diff 未指定」と注記。

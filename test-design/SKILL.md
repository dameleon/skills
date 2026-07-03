---
name: test-design
description: >-
  結合テスト・外部結合テスト向けのテストケースを設計し、独立レビューで検証してから任意の形式で出力する自律パイプライン。
  任意の対象(コード/仕様書/チケット/API スキーマ/自由記述)を入力に取り、シナリオ観点を主軸+機能結合観点でケースを生成し、
  批判的レビュー subagent が観点漏れ・トレーサビリティ・実施者非依存性を検証して指摘を反映、
  Markdown 表 / CSV(ISO/IEC 25010) / Gherkin など指定形式で出力する。
  Use when the user asks to design integration / external-integration test cases:
  「テスト設計して」「結合テストのケース作って」「外部連携のテストケース」「test design」「integration test cases」.
  実施者(手動/自動・誰が実行するか)は想定しない。
  Do NOT use for unit-test-level cases, nor for *running/executing* tests — this only designs and verifies cases.
argument-hint: "[target] [--scope integration|external|both] [--style scenario|functional|both] [--output md|csv|gherkin|path] [--gate auto|review|approve] [--out-dir path]"
---

# Test Design — 結合/外部結合テストケース設計エージェント

任意の対象から結合・外部結合レベルのテストケースを設計し、独立レビューで検証してから指定形式で出力する。
オーケストレータが全段を自律的に回し(ユーザー操作は最小限)、生成と検証を別々の subagent に委譲する
パイプライン + サブエージェントのハイブリッド構成。ユニットテストや「テストの実行」は対象外。

## 入力と出力(どちらも任意指定)

**入力(対象)**: 第1引数 `<target>`。種別はオーケストレータが見分ける。
- コード(ファイル/ディレクトリ): 結合点・外部依存・公開インターフェースを読み取る
- 仕様書/設計書/ヘルプ: 業務フロー・受入基準・データ契約を抽出
- チケット/PR(番号 or URL): 課題本文と関連変更を Test Basis にする
- API スキーマ(OpenAPI/Proto/GraphQL/SQL DDL 等): I/O 契約・境界・エラーを抽出
- 自由記述: 文章から対象システムと連携先を推定
- 省略時: 現在の差分(`git diff`)や直近の文脈を対象に推定し、不明なら Phase 0 で一度だけ確認

**出力(形式・宛先)**: `--output`。3 つを受け付ける。
- 組み込み形式名 `md` / `csv` / `gherkin`(既定 `md`)
- 任意形式の指定: 模倣すべきサンプル/テンプレのパス、または「この列構成で」等の自由記述
- 宛先パス(`--out-dir` で出力先ディレクトリも指定可)

形式の詳細・正準スキーマ・任意形式の扱いは `output-formats.md` を参照。

## 引数

| 引数 | 既定 | 意味 |
|---|---|---|
| `<target>` | 差分/文脈から推定 | テスト設計の対象 |
| `--scope` | `both` | `integration`(内部結合) / `external`(外部結合) / `both` |
| `--style` | `both` | `scenario`(主軸) / `functional`(機能結合) / `both` |
| `--output` | `md` | `md` / `csv` / `gherkin` / 任意のパス・形式指定 |
| `--gate` | `auto` | 自律度。`auto` / `review` / `approve`(下記) |
| `--out-dir` | `.test-design/<slug>/` | 作業・成果物の出力先 |

## パイプライン(自律実行)

各段の成果物は作業ディレクトリ(`--out-dir`、既定 `.test-design/<slug>/`)に書き、後続段と
レビュー subagent が読めるようにする。作業物は使い捨て可能(`.test-design/` は gitignore 推奨)。
最終成果物は `--output` の宛先にも出す。

### Phase 0 — Intake(オーケストレータ, インライン)
1. **対象を確定**する。`target` の種別を見分ける。省略時は次の優先順で決める。(1) 引数 `target` → (2) `git diff` に変更があればそれ → (3) 直近のユーザー指示で名指しされた対象 → (4) いずれも無い(git 管理外・差分が空を含む)なら手順 5 のフォールバックへ。
2. **出力を確定**する。`--output` の形式(`md`/`csv`/`gherkin`/任意)と宛先、`--scope`/`--style` を確定。形式と拡張子 `{ext}`・写経元テンプレ `{template}` の対応は `output-formats.md` の対応表に従う。
3. **パスと slug を確定**する。この SKILL.md が置かれたディレクトリを `{skill-dir}` とし絶対パス化する(subagent に参照ファイルを読ませるため)。`--out-dir`(既定 `.test-design/<slug>/`)も絶対パス化して `{out-dir}` とする。`<slug>` は `target` 名/チケット番号を kebab-case 化(衝突時は `-2` 連番、推定不能なら `${CLAUDE_SESSION_ID}` 先頭 8 桁)。以降の全 dispatch prompt に、この 2 つの絶対パスと確定値を literal で埋める。
4. **Test Basis** を列挙する。仕様の節・チケット番号・`[REF: path:line]`。
5. 対象・出力が本当に欠けていて推定もできない場合に限り、**一度だけ**まとめて確認する。それ以外は止めずに進む。

### Phase 1 — Analyze & Plan(case-designer subagent / 小規模ならインライン)
対象を読み、テスト可能な項目を抽出して設計計画 `PLAN.md` を作る。
- 結合点・外部依存・業務シナリオ(正常/代替/例外)・状態遷移・データ契約を洗い出す
- 観点マトリクス(`viewpoints.md` の観点 × 抽出項目)で網羅を計画する
- 各項目を **カバレッジ分類** する: テスト可 / 保留(要確認) / 不可(対象外、理由付き)
- 未確定・未確認は正直に Open Questions として残す(推測で埋めない)

### Phase 2 — Generate(case-designer subagent)
計画と `viewpoints.md`・`output-formats.md` に従い、ドラフトケースを生成する(`CASES{ext}`)。
シナリオ観点を主軸に、機能結合観点も併せる。各ケースは正準フィールド(下記)を埋め、
**実施者・ツールに非依存**な手順と、**観測可能な検証ポイント**を持つ期待結果を書く。

### Phase 3 — Verify(case-reviewer subagent, 独立・批判的)
**生成とは別の** subagent を必ず起動して検証する。Phase 1/2 をインライン生成した場合でも、レビューは
fork した subagent に出す(同一文脈での自己レビューは禁止)。独立性の本質は「生成時の思考過程を参照しない fresh なパス」であり、fork はその第一手段。dispatch できない環境では、生成根拠を見ずに `CASES{ext}`+`PLAN.md`+Test Basis だけを再読する別パスで代替してよい。レビュー担当は設計担当の思考過程を見ず、
`CASES{ext}` + `PLAN.md` + Test Basis + `verification.md` のルーブリックだけで粗探しする。
findings を `REVIEW.md` に出す。各 finding に ケースID / 違反項目 / 重大度(blocker|major|minor) /
**分類(修正可|要仕様判断)** / 具体修正案 を付ける。

### Phase 4 — Refine(オーケストレータ, 重大度トリアージ)
finding を「分類」を先に見て、次に「重大度」で処理する。
- 分類が **修正可** → 重大度に応じ修正する。blocker/major は自動修正(該当ケースを修正、必要なら designer を findings 付きで再 dispatch)。minor は安価なら適用、高コストなら備考に残す。
- 分類が **要仕様判断**(真の仕様曖昧・一次情報欠落)→ 捏造せず当該ケースを「保留」+ Open Question 化。`--gate review/approve` では停止して確認。

1 周 = Verify(1回)→Refine(1回)。**最大 2 周**(Verify は最大 3 回)。ある周で **修正可の finding がすべて解消** し、残りが 要仕様判断 のみになったら、上限を待たず早期に収束として打ち切る(一次情報が無いと直せないため追加 Verify は無駄)。
- 2 周後に残った **修正可の blocker** は完了にできない。`--gate auto` でも停止し、サマリ冒頭に未解決 blocker として明示報告する(「保留」に格下げして出力しない)。
- 残った major/minor と要仕様判断の項目は「保留」として明示すれば出力してよい。

### Phase 5 — Output(オーケストレータ)
最終ケースを `--output` の宛先に出す。**宛先の既定解決**: `--output` がパスならそこへ書く。形式名のみ(`md`/`csv`/`gherkin`)または宛先パスの無い形式指定なら、out-dir 内の `CASES{ext}` を最終正本とする(別複製は作らない)。`PLAN.md`/`REVIEW.md` は作業用の中間ファイル。
**任意形式**(独自の列構成・サンプル指定)のときは、`CASES{ext}` に正準スキーマのドラフトを保持し、Phase 5 で指定形式の別ファイル(out-dir 配下の slug 由来名、または指定パス)へ決定的に写像する。reviewer は正準ドラフトをレビューする(`CASES{ext}` は常に正準スキーマを持ち、任意形式の内容を直接は持たない)。
併せて **カバレッジサマリ** を出す(`--gate auto` の提示物 = サマリ + 最終成果物のパス。本体表が小さければインライン提示も可)。
- 観点マトリクスの充足状況(観点ごとのケース有無)
- 分類別件数、カバレッジ分類の合計(テスト可/保留/不可)
- 保留・不可の一覧(理由付き)と残った Open Questions
- 信頼度ラベル別の内訳(🟢/🟡/🔴)

## ゲート(自律度)

| `--gate` | 挙動 |
|---|---|
| `auto`(既定) | 全段を通しで実行し、最終成果物と短い検証サマリだけ提示。停止しない(ユーザー操作最小限) |
| `review` | Phase 3 の findings を適用前に提示して確認を取る |
| `approve` | Phase 1(計画)と Phase 3(検証後)で停止して承認を取る |

`auto` でも、仕様判断が必要な項目は捏造せず「保留 + Open Question」として残し、サマリで報告する。

## 作業ディレクトリ(ブラックボード)

```
<out-dir>/                # 既定 .test-design/<slug>/
├── PLAN.md               # Phase 1: スコープ・抽出項目・観点マトリクス・カバレッジ分類・Open Questions
├── CASES{ext}           # Phase 2/4: ドラフト〜確定ケース
├── REVIEW.md             # Phase 3: 検証 findings(重大度付き)
└── <output>              # Phase 5: --output の宛先に最終成果物
```

再実行は同じ `<out-dir>` を指定すれば、PLAN/CASES を引き継いで途中段から回せる。ただし resume 時も Phase 3(Verify)は現 `CASES{ext}` に対し必ず新規に再実行する。既存の `REVIEW.md` を独立検証の代わりに信用しない(prior CASES は Phase 2 ドラフト扱いとし、Verify を省略しない)。明示的な resume 指示が無いのに out-dir に prior-run の成果物が残っている場合は、`_prior_run/` 等へ退避するか新しい slug を使い、古い成果物を現実行と混在させない。

## サブエージェント dispatch

Agent/Task ツールで起動する。Claude Code では組み込み type を使う(`general-purpose`、読み取り中心の解析は `Explore`)。
Phase 0 で確定した値を **穴埋めして literal で** prompt に渡す(プレースホルダのまま投げない)。
埋める値: `{skill-dir}`(絶対パス) / `{out-dir}`(絶対パス) / `{target}`(解決済みパス or チケット・URL・本文) /
`{scope}` / `{style}` / `{ext}`(`output-formats.md` の対応表) / `{template}`(写経元 `templates/cases.*`) / `{test-basis}`(一次情報リスト)。

**case-designer(Phase 1/2)** 穴埋め骨子:
- 「`{skill-dir}/viewpoints.md` の観点で `{target}` を分析し(scope=`{scope}`, style=`{style}`)、`{skill-dir}/output-formats.md` の正準スキーマと写経元 `{skill-dir}/{template}` に従い `{ext}` 形式でケースを生成。Test Basis は `{test-basis}` を引く。実施者非依存・観測可能な期待結果。未確認は正直に保留。成果を `{out-dir}/PLAN.md` と `{out-dir}/CASES{ext}` に書く」

**case-reviewer(Phase 3)** 穴埋め骨子(独立性を強調):
- 「あなたは批判的レビュー担当。設計者の意図を推測せず、`{out-dir}/CASES{ext}` と `{out-dir}/PLAN.md`・Test Basis だけを根拠に、`{skill-dir}/verification.md` のルーブリックで粗探しせよ。観点漏れ・トレーサビリティ欠落・実施者依存・期待結果の曖昧さ・正常系偏りを重点に。各 finding に ケースID / 違反項目 / 重大度(blocker|major|minor) / 分類(修正可|要仕様判断) / 具体修正案 を付け、`{out-dir}/REVIEW.md` に出力。問題が無ければ空で返す」

レビューは Phase 1/2 をインライン生成した場合でも、必ず生成とは別の fork した subagent 呼び出しにする(自己レビュー禁止)。

**ファイル所有権**: 各 subagent は dispatch で指定したファイルのみ作成・変更し、自分が作っていないファイルを削除しない。orchestrator は subagent の返答内容を正(source of truth)とし、最終成果物は Phase 5 で orchestrator 自身が確定させる(中間ファイルが残存していることに依存しない)。構造チェック(列数・区切りの検算など)は producing subagent の完了報告後に orchestrator 自身が実パーサ等で行う(書き込み途中のファイルや subagent の自己申告で判断しない)。

## 重大度トリアージ

| 重大度 | 例 | 既定アクション |
|---|---|---|
| blocker(修正可) | ケースが誤り/実行不能/仕様矛盾/追跡不能 | 自動修正。2 周後も残れば完了せず停止・冒頭で明示報告 |
| major(修正可) | 観点漏れ、期待結果が曖昧、前提条件欠落、正常系偏り、実施者依存 | 自動修正 |
| minor(修正可) | 表現の重複・冗長・体裁 | 安価なら適用、他は備考 |
| 要仕様判断 | 真の仕様曖昧・一次情報欠落 | 捏造せず保留 + Open Question 化。gate により確認 |

## 正準ケースフィールド

全形式はこのフィールドから写像する(詳細・形式別マッピングは `output-formats.md`)。

`ID` / `観点グループ・観点` / `レベル(結合|外部結合)` / `シナリオ・タイトル` / `前提条件` /
`手順(実施者非依存)` / `テストデータ` / `期待結果 + 観測ポイント` / `Test Basis(一次情報参照)` /
`信頼度(🟢VERIFIED|🟡INFERRED|🔴ASSUMED)` / `カバレッジ(テスト可|保留|不可)` / `備考・未確認`

## 原則

- **実施者非依存**: 手順と検証ポイントは、人手でも自動でも実行できる粒度で書く。特定の自動化ツール/フレームワーク/UI セレクタに依存しない。検証は「テストが通る」ではなく観測可能なシステム出力(API 応答・DB 行・キュー・ログ・ファイル等)で表す。外部系を特定状態にする setup(例: 在庫サービスを応答遅延 5s にする)を前提条件・手順に書くのは許容(観測可能な状態宣言)。禁止は特定ツール名・UI セレクタ・個人マシン前提のみ。
- **トレーサビリティ**: 各ケースに Test Basis(仕様の節・チケット番号・`[REF: path:line]`)を必ず引く。
- **正直さ**: 分からないことは「分からない」と書く。コード未確認なら明示し、信頼度ラベルとカバレッジ分類で不確実性を可視化する。推測で正常系を量産しない。観測可能な副作用は具体的に書き切り、一次情報の無い値(応答コード等)だけを保留+仮定ラベルにする(その1点でケース全体を曖昧にしない)。
- **観点網羅**: シナリオ観点を主軸に、機能結合の観点を併せる。観点ごとに最低1つの確認を残す。

## 詳細リファレンス

- 観点モデル(シナリオ主軸 + 機能結合): `viewpoints.md`
- 検証ルーブリック(レビュー subagent 用)+ 重大度: `verification.md`
- 出力形式・正準スキーマ・任意形式の扱い・テンプレート: `output-formats.md`(`templates/` 配下に各形式のひな型)

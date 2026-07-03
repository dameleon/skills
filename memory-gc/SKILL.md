---
name: memory-gc
description: >
  Garbage-collect Claude Code auto-memory across all projects: inventory every
  memory entry under the projects root (default ~/.claude/projects; a custom
  root can be passed as the first argument for partial GC or testing),
  empirically verify testable claims to
  detect staleness, classify each entry as discard / promote to
  ~/.claude/CLAUDE.md / migrate to the repo's CLAUDE.local.md / keep as
  knowledge, then execute only after explicit user approval.
  Use when the user says "/memory-gc", "メモリのGC", "メモリ整理",
  "memory 掃除", "メモリを掃除して", "memory cleanup", or asks to audit,
  prune, or refactor Claude's accumulated memories. Recommended cadence:
  monthly, or when a MEMORY.md approaches the auto-load cap (200 lines / 25KB).
  Destructive steps are gated behind user approval; never edits team-tracked
  CLAUDE.md files.
disable-model-invocation: true
argument-hint: "[projects-root] [--report-only]"
---

# memory-gc — auto memory の定期 GC

auto memory は自律的に書かせる。その代わりこの GC で定期的に「検証・刈り込み・再配置」を行い、
メモリの3大劣化（陳腐化 / 階層違反 / 重複）を回収する。

## 引数

- `$0`（任意）: 走査対象の projects ルート。省略時は `~/.claude/projects`。テストや部分 GC ではここを差し替える
- `--report-only`: Step 4 の提案レポートで終了し、承認フロー・実行を行わない（非対話実行時もこの挙動にフォールバック）

## 前提: 3層アーキテクチャ

メモリの内容は本来あるべき層に置く。GC とは、誤った層にあるエントリを正しい層へ動かす（または捨てる）こと。

| 層 | 置き場所 | ロード | 置くべきもの |
|---|---|---|---|
| 全プロジェクト共通ルール | `~/.claude/CLAUDE.md` | 常時 | 複数プロジェクトで独立に現れた普遍的な運用ルール |
| プロジェクト個人ルール | 各リポジトリ直下 `CLAUDE.local.md`（git 管理外） | そのプロジェクトで常時 | 命令形で常時効かせたいプロジェクト固有ルール |
| 知識・事実 | `<projects-root>/<dir>/memory/` | オンデマンド | 設計判断・確定事項・日付つきの環境 Tips |

## Workflow

### Step 1: Inventory（走査）

`<projects-root>/*/memory/` を全走査し、全ファイルを表にする:

| プロジェクト | ファイル | 種別 | 最終更新 | 概要(1行) |
|---|---|---|---|---|

「最終更新」は本文・frontmatter に記録日があればそれを優先し、なければ mtime を使う（fixture や一括コピー直後は mtime が無情報になるため）。

対象集合の定義: **inventory は MEMORY.md を含む全 .md ファイル**。ただし Step 3 の4分類の対象は**索引（MEMORY.md）を除くエントリのみ**で、索引自体は分類せず、不整合修正（Step 5）の対象として別枠で扱う。

種別は内容から判定する: **rule**（命令形の運用指示）/ **knowledge**（設計判断・事実）/ **tips**（環境トラブル対処）/ **索引**（MEMORY.md。分類対象外だが列挙対象）。
判定シグナルの詳細は `reference.md` の「種別判定」を読む。MEMORY.md 索引と実ファイルの不整合（索引にない実体・実体のない索引）もここで検出する。

### Step 2: Verify（陳腐化検証）

各エントリの主張を2種に分け、検証する:

- **実測可能な主張**（CLI 挙動・承認ダイアログの有無・ツール/パスの存在・設定値）: 実際にコマンドを実行して現在も成立するか確かめる。検証コマンドは**読み取り専用・無害なものに限る**（実例は `reference.md`）
- **検証不能な主張**（チーム運用・外部仕様・過去の決定）: 日付の古さ、対象（PR/issue/ブランチ）の現状、他ファイル・settings との矛盾から stale 候補を判定する

settings.json / CLAUDE.md / CLAUDE.local.md と**矛盾するメモリ**は最優先で検出する。どちらが現状正しいかを実測か質問で確定させる。

### Step 3: Classify（振り分け）

複数の条件が同時成立しうるため、判定は必ずこの順で適用する:
**(1) 上位層（CLAUDE.md / CLAUDE.local.md / settings）との重複・陳腐化チェック → 破棄**、(2) 昇格判定、(3) 移管判定、(4) 残置。
例: 2プロジェクトに同じ教訓があっても、すでに上位層へ反映済みなら「昇格」でなく「破棄（重複）」。

各エントリを4つに分類する:

| 分類 | 条件 |
|---|---|
| **破棄** | 陳腐化が確認された / 他の層・他のメモリと重複 / 対象案件が終了して参照価値がない。**環境依存の実測のみを根拠とする場合は「破棄（環境条件付き）」として無条件破棄と表上で区別**し、最終判断を承認に委ねる |
| **昇格** → `~/.claude/CLAUDE.md` | 2つ以上のプロジェクトで独立に現れた普遍ルール（例外: 単一出現でも内容が明確にプロジェクト非依存なら候補。判定基準の正は本表で、`reference.md` は補足） |
| **移管** → 該当リポジトリの `CLAUDE.local.md` | 命令形のプロジェクト固有ルール。原則メモリに残さない（メモリ内のルールはプロジェクトルールを上書きする事故の元）。移管先リポジトリのパスは memory ディレクトリ名から復元し（先頭 `-` 区切り → パス区切り。`-` がパス区切りか名前の一部か一意に定まらない場合は候補を列挙して存在確認する）、**提案前に存在を確認**する。存在しない場合は提案表に「移管先不明」と明記して残置にフォールバックする。このフォールバックは**暫定措置**であり、解消条件（ユーザーによる移管先パスの指定）をレポートの次アクションに必ず記載する |
| **残置** | knowledge / 日付つき tips。MEMORY.md 索引から1行で引ける状態にする |

迷ったら破棄ではなく残置に倒す（誤削除は不可逆、残置のコストはオンデマンドなのでほぼゼロ）。

### Step 4: Propose & approve（提案と承認）

振り分け結果を分類ごとの表で提示し、**ユーザーの明示承認を得る**。表には各エントリの「分類理由」と「検証結果（実測したものはその証拠）」を含める。

- 承認なしに **Step 5 に列挙されたすべての操作**（削除・移管・昇格に加え、MEMORY.md 索引更新を含む）を実行しない。ガード対象は操作の種類列挙ではなく「Step 5 全体」で定義する
- `--report-only` 指定時、または対話できない実行文脈では、ここでレポートを出力して終了する。終了時はレポート末尾に**ユーザーが次に取るアクション**（承認の伝え方の例:「破棄3件すべて承認」「○○以外承認」、再開方法: 承認文言を添えて `/memory-gc` を再実行）を必ず含める。提案が0件の縮退ケースでは「実行すべき操作なし・再実行不要」と書けばよい（承認文言の例を無理に構成しない）
- ユーザーが一部だけ承認した場合は承認分のみ実行する

### Step 5: Execute（実行と索引更新）

承認後に以下を行う:

1. 昇格: `~/.claude/CLAUDE.md` に追記（既存記述と重複しない形に統合）
2. 移管: 該当リポジトリ直下の `CLAUDE.local.md` に追記または新規作成（untracked のまま置く）。**チームの tracked CLAUDE.md は絶対に編集しない**
3. 破棄: 対象ファイルを削除する
4. 各 `memory/MEMORY.md` 索引を残存エントリのみに更新

横断インデックス（`~/.claude/memory-index.md`）と破棄履歴は維持しない。自動ロードされず読まれないため、索引は自動ロードされる各 `memory/MEMORY.md` のみとする。

最後に、実行結果のサマリ（昇格/移管/破棄/残置の件数と行き先）を報告する。

## 安全制約（常に適用）

- 検証コマンドは読み取り専用・無害なものに限る。検証のために状態を変えない
- 削除・移管・昇格は Step 4 の承認後のみ
- チームの tracked CLAUDE.md / プロジェクトの git 管理ファイルを編集しない（CLAUDE.local.md は untracked なので可）
- 削除前に対象ファイルの内容を読み、提案時の説明と食い違っていたら提案をやり直す

種別判定のシグナル、検証コマンドの実例、CLAUDE.local.md 運用の注意点、索引ファイルの書式は `reference.md` を読む。

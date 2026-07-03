<!-- agent-flow:meta
flow: <slug>            # prefix を含めない bare kebab 名（branch 生成時に付与）
branch: <type>/<slug>   # type = fix（バグ修正）/ feat（機能追加）
pr:                     # PR 作成後に番号を埋める
phase: 1
engine: subagent        # subagent（既定）/ goal / ralph。goal・ralph は gateless 限定
storage: github
-->

## 概要
<何を・なぜやるか。数行。前提（環境・依存）も。元チケットがあれば `関連: #<番号>` をここに。
 リンク先チケットから導ける内容は貼らない。>

## 設計 (PLAN)
<設計判断・アーキテクチャ・制御フロー（ゲート位置とその理由、engine）。
 goal/ralph なら完了条件 / 再投入プロンプト＋フレーズ＋上限もここに。
 長くなる場合は本文に要約だけ置き、詳細はコメント or 別ドキュメントへリンク（本文上限 65,536 文字）。>

<!-- 既定: 全フェーズ gate: none で draft PR まで一気通貫し、PR を自己レビューする。
 チェックポイントは「開いた draft PR ＋ 投稿された自動レビューコメント」— ローカルで黙って止まる approve
 ではなく外的に観測可能な成果物に置く。approve は不可逆な副作用（本番マイグレーション/デプロイ/外部送信）の
 手前にだけ置く。trivial な変更では PR レビュー段を省いてよい。ロールは必ずバッククォートで囲う（@メンション化防止）。 -->

## Phase 1: 実装  <!-- gate: none -->
- [ ] <タスク> `@implement`                     # app→テスト→lint→/simplify の内側ループはロール契約
  - done: アプリ＋テスト実装済み・test+lint green・diff 簡潔化済み
- [ ] 動作確認 `@test`                           # @implement の単体検証を超える確認が要る時だけ
  - done: テスト＋lint green（必要ならブラウザ確認も）
- [ ] PR 作成（draft / PR テンプレ準拠 / PR 本文に `Closes #<この issue>`） `@pr`
  - done: ドラフト PR が開かれ、meta の pr: が埋まり、PR 本文に Closes 記載（番号は @pr が解決。issue 本文には不要）

## Phase 2: PR レビュー  <!-- gate: none -->     # 既定 ON（trivial 変更では省略可）。レビューは @pr-review タスクが実施
- [ ] PR レビュー（inline コメント投稿＋重大度トリアージ） `@pr-review`
  - done: 指摘が PR にコメント済み。in-scope は下の `@fix`、out-of-scope は別 follow-up issue

## Phase 3: レビュー修正  <!-- gate: none -->
<`@pr-review` が in-scope 指摘を `@fix` として追記。push 後は対応する PR スレッドを resolve>

<!-- 代替: risk に応じてゲートを足す場合の例（既定では使わない）
## Phase 0: 詳細設計  <!-- gate: review -->     # 設計完了後にレビュー（risk 次第で approve / none）
- [ ] <タスク> `@design`
  - done: 設計（PLAN）節が更新済み

## Phase N: <不可逆操作>  <!-- gate: approve -->  # 本番マイグレーション/デプロイ/外部送信の前にだけ人間承認
- [ ] <タスク> `@implement`
  - done: <客観基準>
-->

<!-- 注記（このテンプレ自体の使い方。issue 本文には残さない）:
 - フェーズ見出しは local の TASKS.md と同じ `## Phase N: ... <!-- gate: ... -->`。
   `## 概要` / `## 設計` はその上に置く兄弟見出し（`Phase` キーワードで grep は曖昧にならない）。
 - チェックリスト・goal/done・gate マーカーは local と完全一致。
 - 本文を編集するのは run オーケストレータのみ（single-writer）。編集直前に必ず再取得する。
-->

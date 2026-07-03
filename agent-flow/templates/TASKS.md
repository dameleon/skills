---
flow: <slug>            # prefix を含めない bare kebab 名（branch 生成時に付与）
branch: <type>/<slug>   # type = fix（バグ修正）/ feat（機能追加）
pr:
phase: 1
engine: subagent        # subagent（既定）/ goal / ralph。goal・ralph は gateless 限定（SKILL.md 参照）
---
# TASKS

> このファイルは作業中いつでも更新してよい。新たに必要になったタスクは該当フェーズに
> `- [ ]` を追記し、完了したら `[x]` にする。フェーズ構成・ゲート・engine は設計（PLAN.md）が決める。
>
> 1 フェーズ = ゲートで区切られたタスク群。ゲートは **フェーズ完了時**（次フェーズへ進む前の
> チェックポイント）に発火する。各 `<!-- gate: ... -->` の値は risk で選ぶ。
>
> **既定**: 下記のとおり全フェーズ `gate: none` で draft PR まで一気通貫し、PR を自分でレビューする。
> チェックポイントは「開いた draft PR ＋ 投稿された自動レビューコメント」— ローカルで黙って止まる
> approve ゲートではなく、外的に観測可能な成果物に置く（端末を離れても完了が死蔵されない）。
> approve は**不可逆な副作用**（本番マイグレーション実行・デプロイ・外部送信）を持つタスクの手前にだけ置く。
> trivial な変更では PR レビュー段を省いてよい。
> engine が goal/ralph でも、このタスク一覧は反復間の進捗台帳として維持する（run が 1 件ずつ消化する）。

## Phase 1: 実装  <!-- gate: none -->
- [ ] <タスク> @implement                       # app→テスト→lint→/simplify の内側ループはロール契約（run.md）
  - goal: <ゴール>
  - done: アプリ＋テスト実装済み・test+lint green・diff 簡潔化済み
- [ ] 動作確認 @test                             # @implement の単体検証を超える確認が要る時だけ
  - done: テスト＋lint green（必要ならブラウザ確認も）
- [ ] PR 作成（draft / PR テンプレ準拠） @pr
  - done: ドラフト PR が開かれ、ヘッダ pr: が埋まる

## Phase 2: PR レビュー  <!-- gate: none -->     # 既定 ON（trivial 変更では省略可）。レビューは @pr-review タスクが実施
- [ ] PR レビュー（inline コメント投稿＋重大度トリアージ） @pr-review
  - goal: review-pr の指摘を PR に inline 投稿し、本PR対応 / スコープアウトへ振り分ける
  - done: 指摘が PR にコメント済みで、in-scope は下の @fix、out-of-scope は follow-up issue になっている

## Phase 3: レビュー修正  <!-- gate: none -->
<@pr-review が in-scope 指摘を @fix として追記。push 後は対応する PR スレッドを resolve>

<!-- 代替: risk に応じてゲートを足す場合の例（既定では使わない）
## Phase 0: 詳細設計  <!-- gate: review -->     # 設計完了後にレビュー（risk 次第で approve / none）
- [ ] <タスク> @design
  - done: PLAN.md の設計節が更新済み

## Phase N: <不可逆操作>  <!-- gate: approve -->  # 本番マイグレーション/デプロイ/外部送信の前にだけ人間承認
- [ ] <タスク> @implement
  - done: <客観基準>
-->

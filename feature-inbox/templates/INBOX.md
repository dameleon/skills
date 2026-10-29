<!-- feature-inbox:meta
feature: <slug>               # kebab-case の短い識別子（検索・pointer 用）
tracker: github
opened: <YYYY-MM-DD>
last-ids: Q=0 I=0 H=0         # 直近に払い出した ID。post が加算する
summarized-through:           # summary が畳み込んだ最後のコメント id / 日付
-->

## 概要
<何の feature / epic か。数行。設計ドキュメント・元 epic issue・関連 issue へのリンク。
 リンク先から導ける内容は貼らない。>

## 使い方
- 未決事項・課題・作業報告・引継ぎは、この issue のコメントに `### [未決] Q-n:` / `### [課題] I-n:` /
  `### [報告]` / `### [引継ぎ] H-n:` / `### [決定] → Q-n:` の見出しで書く（`/feature-inbox post`）。
  エージェントが自分で決めたことも `### [決定] Q-n:`（決定者: エージェント）として残す。
- タスク単位の issue があるときは、作業の詳細報告はそちらのコメントに書き、ここにはそのリンクと
  引継ぎ・課題・feature 横断の未決/決定だけを残す。
- 下のサマリ領域は `/feature-inbox summary` が書き換える。自由記述は「メモ」以下へ。

<!-- feature-inbox:summary:start -->
## 最新状況
_（未集約）_

## 未決リスト
_（なし）_

## 課題
_（なし）_

## 決定済み
_（なし）_

## 引継ぎ・注意
_（なし）_
<!-- feature-inbox:summary:end -->

## メモ
_自由記述欄。人間・エージェントどちらが書いてもよく、スキルはここを書き換えない。_

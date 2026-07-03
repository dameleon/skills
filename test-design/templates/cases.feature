# 対象 (Target): <入力の概要>
# スコープ: integration | external | both / スタイル: scenario | functional | both
# 観点はタグで表現: @scenario @contract @data-integrity @resilience @cross-cutting @regression
#                  @integration / @external、異常系は @timeout @retry @idempotency など

@integration
Feature: 注文確定(カート→在庫引当→注文確定)
  # 対象連携: 注文サービス ⇔ 在庫サービス / Test Basis: 仕様§3 注文

  # Test Basis: 仕様§3.2 注文確定 / [REF: order/api.rb:42]
  # 信頼度: 🟢 VERIFIED / カバレッジ: テスト可
  @scenario
  Scenario: 正常フロー: 在庫のある商品を注文確定できる
    Given ユーザが認証済みで、カートに在庫品が1点ある
    And 在庫サービスが正常に応答する
    When 注文確定 API に有効なカートIDで POST する
    Then 応答は 201 で orderId を含む
    And orders テーブルの行が 1 件増える
    And order.created メッセージがキューに 1 件入る
    And 在庫が 1 減る

  # Test Basis: 仕様§5.1 外部連携の回復性 / [REF: order/api.rb:88]
  # 信頼度: 🟡 INFERRED(リトライ回数の仕様未確認) / カバレッジ: 保留(5s 行のみ。閾値超過時の挙動が未確定)
  @external @resilience @timeout
  Scenario Outline: 在庫サービスの応答遅延しきい値での注文確定の挙動
    Given 在庫サービスの応答遅延が <delay> である(タイムアウト閾値 3s)
    When 注文確定 API に POST する
    Then 応答は <status> である
    And orders テーブルの行は <orders_delta> 件変化する
    And エラーログの相関ID記録は <error_log> である

    Examples:
      | delay | status | orders_delta | error_log |
      | 5s    | 503    | 0            | あり      |
      | 2s    | 201    | +1           | なし      |

#!/usr/bin/env bash
# codex-review: codex CLI を使ったコードレビュー・プランレビューの実行スクリプト
# 出力はファイルに書き出し、セッションIDを抽出して返す
set -euo pipefail

MODE="${1:?Usage: codex_review.sh <mode> [args...]}"
shift

OUTPUT_DIR="${CODEX_REVIEW_OUTPUT_DIR:-/tmp/codex-review}"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/review_${TIMESTAMP}.md"
SESSION_FILE="${OUTPUT_DIR}/session_${TIMESTAMP}.txt"

# ヘルパー: diff + カスタムプロンプトを codex exec 経由で実行
# codex review は --uncommitted/--base/--commit とPROMPT引数を併用できないため、
# プロンプト付きの場合は diff をテンプファイルに書き出して codex exec に渡す
run_review_with_prompt() {
  local diff_content="$1"
  local user_prompt="$2"
  local diff_file="${OUTPUT_DIR}/diff_${TIMESTAMP}.patch"

  echo "$diff_content" > "$diff_file"

  local prompt
  prompt="以下の git diff をコードレビューしてください。
各指摘には重要度(CRITICAL/WARNING/INFO)を付けてください。

--- レビュー指示 ---
${user_prompt}
---

diff は ${diff_file} に保存されています。ファイルを読んでレビューしてください。
変更されたファイルの全体を読むことで、diff の前後のコンテキストも確認してください。"

  codex exec -s read-only -o "$OUTPUT_FILE" "$prompt" 2>&1
  cat "$OUTPUT_FILE"
}

case "$MODE" in
  # コードレビュー: uncommitted changes
  code-uncommitted)
    PROMPT="${1:-}"
    if [[ -n "$PROMPT" ]]; then
      DIFF=$(git diff 2>&1 || true)
      DIFF_STAGED=$(git diff --cached 2>&1 || true)
      run_review_with_prompt "${DIFF}${DIFF_STAGED:+
${DIFF_STAGED}}" "$PROMPT"
    else
      codex review --uncommitted 2>&1 | tee "$OUTPUT_FILE"
    fi
    ;;

  # コードレビュー: base branch 比較
  code-base)
    BASE="${1:?base branch required}"
    PROMPT="${2:-}"
    if [[ -n "$PROMPT" ]]; then
      DIFF=$(git diff "${BASE}"...HEAD 2>&1 || true)
      run_review_with_prompt "$DIFF" "$PROMPT"
    else
      codex review --base "$BASE" 2>&1 | tee "$OUTPUT_FILE"
    fi
    ;;

  # コードレビュー: 特定のコミット
  code-commit)
    SHA="${1:?commit SHA required}"
    PROMPT="${2:-}"
    if [[ -n "$PROMPT" ]]; then
      DIFF=$(git show "$SHA" 2>&1 || true)
      run_review_with_prompt "$DIFF" "$PROMPT"
    else
      codex review --commit "$SHA" 2>&1 | tee "$OUTPUT_FILE"
    fi
    ;;

  # プラン/設計レビュー: exec モードで実行
  plan)
    PLAN_FILE="${1:?plan file path required}"
    EXTRA_PROMPT="${2:-}"
    PLAN_CONTENT=$(cat "$PLAN_FILE")
    PROMPT="以下のプラン/設計ドキュメントをレビューしてください。
問題点、改善提案、リスク、見落としなどを指摘してください。
各指摘には重要度(CRITICAL/WARNING/INFO)を付けてください。

--- プラン ---
${PLAN_CONTENT}
---

${EXTRA_PROMPT}"
    codex exec -s read-only -o "$OUTPUT_FILE" "$PROMPT" 2>&1
    cat "$OUTPUT_FILE"
    ;;

  # カスタムプロンプトでのレビュー (exec)
  custom)
    PROMPT="${1:?prompt required}"
    codex exec -s read-only -o "$OUTPUT_FILE" "$PROMPT" 2>&1
    cat "$OUTPUT_FILE"
    ;;

  # セッション再開でのフォローアップレビュー
  resume)
    SESSION_ID="${1:?session ID required}"
    PROMPT="${2:?follow-up prompt required}"
    codex exec resume "$SESSION_ID" -o "$OUTPUT_FILE" "$PROMPT" 2>&1
    cat "$OUTPUT_FILE"
    ;;

  *)
    echo "Unknown mode: $MODE"
    echo "Modes: code-uncommitted, code-base, code-commit, plan, custom, resume"
    exit 1
    ;;
esac

# 最新のセッションIDを抽出して保存
LATEST_SESSION=$(ls -t ~/.codex/sessions/$(date +%Y)/$(date +%m)/$(date +%d)/ 2>/dev/null | head -1 | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' || echo "")
if [[ -n "$LATEST_SESSION" ]]; then
  echo "$LATEST_SESSION" > "$SESSION_FILE"
  echo ""
  echo "---"
  echo "SESSION_ID: $LATEST_SESSION"
  echo "OUTPUT_FILE: $OUTPUT_FILE"
  echo "SESSION_FILE: $SESSION_FILE"
fi

#!/usr/bin/env bash
# copilot-review: GitHub Copilot CLI を使ったコードレビュー・プランレビューの実行スクリプト
# 出力はファイルに書き出し、セッション情報を返す
set -euo pipefail

MODE="${1:?Usage: copilot_review.sh <mode> [args...]}"
shift

OUTPUT_DIR="${COPILOT_REVIEW_OUTPUT_DIR:-/tmp/copilot-review}"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/review_${TIMESTAMP}.md"

# 共通オプション: read-onlyツールのみ許可、サイレント出力
COPILOT_OPTS=(--available-tools read -s --share "$OUTPUT_FILE")

# ヘルパー: diff + カスタムプロンプトを copilot -p 経由で実行
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

  copilot -p "$prompt" "${COPILOT_OPTS[@]}" 2>&1
  echo ""
  echo "---"
  echo "OUTPUT_FILE: $OUTPUT_FILE"
}

# ヘルパー: シンプルなプロンプト実行
run_prompt() {
  local prompt="$1"
  copilot -p "$prompt" "${COPILOT_OPTS[@]}" 2>&1
  echo ""
  echo "---"
  echo "OUTPUT_FILE: $OUTPUT_FILE"
}

case "$MODE" in
  # コードレビュー: uncommitted changes
  code-uncommitted)
    PROMPT="${1:-}"
    DIFF=$(git diff 2>&1 || true)
    DIFF_STAGED=$(git diff --cached 2>&1 || true)
    COMBINED="${DIFF}${DIFF_STAGED:+
${DIFF_STAGED}}"
    if [[ -z "$COMBINED" ]]; then
      echo "No uncommitted changes found."
      exit 0
    fi
    if [[ -n "$PROMPT" ]]; then
      run_review_with_prompt "$COMBINED" "$PROMPT"
    else
      run_review_with_prompt "$COMBINED" "標準的なコードレビューを行ってください。"
    fi
    ;;

  # コードレビュー: base branch 比較
  code-base)
    BASE="${1:?base branch required}"
    PROMPT="${2:-}"
    DIFF=$(git diff "${BASE}"...HEAD 2>&1 || true)
    if [[ -z "$DIFF" ]]; then
      echo "No diff found against base branch: $BASE"
      exit 0
    fi
    if [[ -n "$PROMPT" ]]; then
      run_review_with_prompt "$DIFF" "$PROMPT"
    else
      run_review_with_prompt "$DIFF" "標準的なコードレビューを行ってください。"
    fi
    ;;

  # コードレビュー: 特定のコミット
  code-commit)
    SHA="${1:?commit SHA required}"
    PROMPT="${2:-}"
    DIFF=$(git show "$SHA" 2>&1 || true)
    if [[ -n "$PROMPT" ]]; then
      run_review_with_prompt "$DIFF" "$PROMPT"
    else
      run_review_with_prompt "$DIFF" "標準的なコードレビューを行ってください。"
    fi
    ;;

  # プラン/設計レビュー: プロンプトモードで実行
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
    run_prompt "$PROMPT"
    ;;

  # カスタムプロンプトでのレビュー
  custom)
    PROMPT="${1:?prompt required}"
    run_prompt "$PROMPT"
    ;;

  # セッション再開でのフォローアップレビュー
  resume)
    SESSION_ID="${1:?session ID required}"
    PROMPT="${2:?follow-up prompt required}"
    copilot --resume "$SESSION_ID" -p "$PROMPT" "${COPILOT_OPTS[@]}" 2>&1
    echo ""
    echo "---"
    echo "OUTPUT_FILE: $OUTPUT_FILE"
    ;;

  *)
    echo "Unknown mode: $MODE"
    echo "Modes: code-uncommitted, code-base, code-commit, plan, custom, resume"
    exit 1
    ;;
esac

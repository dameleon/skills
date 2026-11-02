#!/usr/bin/env bash
# delegate.sh — hand a task to cursor-agent headlessly, acceptance-check it with a shell command,
# resume-fix on failure, and print a concise verdict. No LLM sits between the caller and Cursor:
# the loop, the acceptance decision, and the fix prompt are all mechanical.
#
# Usage:
#   delegate.sh --accept '<shell cmd>' [--model auto] [--rounds 2] [--workdir DIR] [--] "<task>"
#   echo "<task>" | delegate.sh --accept '<shell cmd>'
#
# Exit codes: 0 PASS / 1 NG (check still failing) / 2 usage or preflight / 3 cursor-agent error
set -u

MODEL="auto"; ROUNDS=2; WORKDIR="$PWD"; ACCEPT=""; TASK=""
die() { echo "status: failed"; echo "notes: $*"; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --accept)  ACCEPT="${2-}"; shift 2 ;;
    --model)   MODEL="${2-}"; shift 2 ;;
    --rounds)  ROUNDS="${2-}"; shift 2 ;;
    --workdir) WORKDIR="${2-}"; shift 2 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    --) shift; TASK="$*"; break ;;
    -*) die "unknown option: $1" ;;
    *)  TASK="$*"; break ;;
  esac
done
[ -z "$TASK" ] && [ ! -t 0 ] && TASK="$(cat)"
[ -n "$TASK" ]   || die "no task given"
[ -n "$ACCEPT" ] || die "--accept '<shell cmd>' is required: an objective check is the only acceptance signal"
case "$ROUNDS" in ''|*[!0-9]*) die "--rounds must be a non-negative integer" ;; esac
command -v cursor-agent >/dev/null || die "cursor-agent not found on PATH"
command -v jq >/dev/null           || die "jq not found on PATH"
cd "$WORKDIR" 2>/dev/null          || die "cannot cd to $WORKDIR"
IS_GIT=0; git rev-parse --is-inside-work-tree >/dev/null 2>&1 && IS_GIT=1

LOG="$(mktemp -d "${TMPDIR:-/tmp}/cursor-delegate.XXXXXX")"

# Snapshot of the dirty tree as "path<TAB>blob-hash"; diffing two snapshots yields exactly the
# paths cursor-agent touched, even when the tree was already dirty before delegation.
snap() {
  [ "$IS_GIT" = 1 ] || return 0
  git status --porcelain=v1 -z -uall --no-renames | while IFS= read -r -d '' rec; do
    p="${rec:3}"
    if [ -e "$p" ]; then h="$(git hash-object -- "$p")"; else h=deleted; fi
    printf '%s\t%s\n' "$p" "$h"
  done | sort
}

SESSION=""; USED_MODEL="$MODEL"; RESULT=""; RUN_N=0
# run_cursor <prompt> → sets RESULT/SESSION; returns 0 ok / 3 hard error
run_cursor() {
  local prompt="$1" out err rc
  RUN_N=$((RUN_N + 1)); out="$LOG/run$RUN_N.json"; err="$LOG/run$RUN_N.err"
  if [ -n "$SESSION" ]; then
    cursor-agent -p --output-format json -f --trust --resume "$SESSION" "$prompt" >"$out" 2>"$err"
  else
    cursor-agent -p --output-format json -f --trust --model "$USED_MODEL" "$prompt" >"$out" 2>"$err"
  fi
  rc=$?
  local is_err subtype
  # not `.is_error // "true"`: jq's `//` treats a literal false as missing and would flip it
  is_err="$(jq -r 'if has("is_error") then (.is_error | tostring) else "true" end' "$out" 2>/dev/null || echo true)"
  subtype="$(jq -r '.subtype // ""' "$out" 2>/dev/null || echo "")"
  RESULT="$(jq -r '.result // ""' "$out" 2>/dev/null)"
  local sid; sid="$(jq -r '.session_id // ""' "$out" 2>/dev/null)"; [ -n "$sid" ] && SESSION="$sid"
  if [ "$rc" -eq 0 ] && [ "$is_err" = "false" ] && [ "$subtype" = "success" ]; then return 0; fi
  ERRTEXT="$(printf '%s\n%s' "$RESULT" "$(cat "$err")" | tr '\n' ' ' | cut -c1-400)"
  return 3
}
classify() {
  local t; t="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$t" in
    *"not logged in"*|*authenticat*|*"cursor-agent login"*) echo auth ;;
    *"rate limit"*|*"usage limit"*|*quota*|*exceeded*|*unavailable*|*"not available"*|*insufficient*|*402*|*429*|*payment*|*"cannot use this model"*) echo limit ;;
    *) echo other ;;
  esac
}
# paths_between <snapA> <snapB> → one path per line that differs between the two snapshots
paths_between() { comm -3 <(printf '%s\n' "$1") <(printf '%s\n' "$2") | sed 's/^\t//' | cut -f1 | grep -v '^$' | sort -u; }
join_list() { paste -sd, - | sed 's/,/, /g'; }
report() {  # report <status> <acceptance> <exit>
  local changed artifacts
  if [ "$IS_GIT" = 1 ]; then
    # files the acceptance check itself produced (__pycache__, build output) are not cursor's edits
    changed="$(comm -23 <(paths_between "$BEFORE" "$(snap)") <(printf '%s' "$CHECK_PATHS" | sort -u) | join_list)"
    artifacts="$(printf '%s' "$CHECK_PATHS" | sort -u | grep -v '^$' | join_list)"
  else
    changed="(not a git repo — unknown)"
  fi
  echo "status: $1"
  echo "model: $USED_MODEL"
  echo "changed: ${changed:-none}"
  [ -n "${artifacts:-}" ] && echo "check artifacts: $artifacts"
  echo "acceptance: $2"
  echo "fix rounds: $FIXES"
  echo "session: ${SESSION:-none}"
  echo "cursor summary: $(printf '%s' "$RESULT" | tr '\n' ' ' | cut -c1-500)"
  echo "logs: $LOG"
  exit "$3"
}

BEFORE="$(snap)"; FIXES=0; ERRTEXT=""; CHECK_PATHS=""
if ! run_cursor "$TASK"; then
  kind="$(classify "$ERRTEXT")"
  if [ "$kind" = limit ] && [ "$USED_MODEL" != auto ]; then
    USED_MODEL=auto; SESSION=""
    run_cursor "$TASK" || report failed "NG — cursor-agent error after fallback to auto ($(classify "$ERRTEXT")): $ERRTEXT" 3
  else
    report failed "NG — cursor-agent error ($kind): $ERRTEXT" 3
  fi
fi

while :; do
  pre="$(snap)"
  ( bash -c "$ACCEPT" ) >"$LOG/accept$FIXES.out" 2>&1; arc=$?
  CHECK_PATHS="$CHECK_PATHS$(paths_between "$pre" "$(snap)")
"
  if [ "$arc" -eq 0 ]; then
    report done "PASS — \`$ACCEPT\` exit 0" 0
  fi
  if [ "$FIXES" -ge "$ROUNDS" ]; then
    report failed "NG — \`$ACCEPT\` exit $arc after $FIXES fix round(s): $(tail -n 5 "$LOG/accept$FIXES.out" | tr '\n' ' ' | cut -c1-300)" 1
  fi
  FIXES=$((FIXES + 1))
  fix_prompt="The acceptance check for your previous change failed.
Command: $ACCEPT
Exit code: $arc
Last output:
\`\`\`
$(tail -n 40 "$LOG/accept$((FIXES - 1)).out")
\`\`\`
Fix the code so this check passes. Stay within the original task's scope and do not weaken or edit the check itself."
  run_cursor "$fix_prompt" || report failed "NG — cursor-agent error during fix round $FIXES ($(classify "$ERRTEXT")): $ERRTEXT" 3
done

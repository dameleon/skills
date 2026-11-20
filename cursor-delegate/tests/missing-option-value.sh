#!/usr/bin/env bash
# A value-taking option given without its value must make delegate.sh exit 2 with
# "status: failed" and "notes: <opt> requires a value", and never hang. Each case runs
# under a 5-second alarm. The last case is a control: a valid pair passes the guard and
# stops in the script's own preflight, before cursor-agent is looked up.
set -u

script="$(cd "$(dirname "$0")/../scripts" && pwd)/delegate.sh"
fail=0

# check <label> <want-notes-line> <forbidden-text-or-empty> -- <args...>
check() {
  label="$1"; want="$2"; forbid="$3"; shift 4
  out="$(perl -e 'alarm 5; exec @ARGV' "$script" "$@" </dev/null 2>&1)"
  rc=$?
  if [ "$rc" -eq 2 ] \
    && printf '%s\n' "$out" | grep -qx 'status: failed' \
    && printf '%s\n' "$out" | grep -qxF "$want" \
    && { [ -z "$forbid" ] || ! printf '%s\n' "$out" | grep -qF "$forbid"; }; then
    echo "ok   $label"
  else
    echo "FAIL $label: exit $rc (want 2), want line '$want', output: ${out:-<none>}"
    fail=1
  fi
}

for opt in --accept --model --rounds --workdir; do
  check "$opt" "notes: $opt requires a value" "" -- "$opt"
  check "--accept true $opt" "notes: $opt requires a value" "" -- --accept true "$opt"
done

check "valid pair passes the guard" "notes: --rounds must be a non-negative integer" \
  "requires a value" -- --accept true --rounds x t

exit "$fail"

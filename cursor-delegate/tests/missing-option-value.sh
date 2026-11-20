#!/usr/bin/env bash
# A value-taking option given without its value is a usage error: delegate.sh must print
# "status: failed" and exit 2. Each case runs under a 5-second alarm, because the failure
# this guards against is the script never returning.
set -u

script="$(cd "$(dirname "$0")/../scripts" && pwd)/delegate.sh"
fail=0

for opt in --accept --model --rounds --workdir; do
  out="$(perl -e 'alarm 5; exec @ARGV' "$script" "$opt" </dev/null 2>&1)"
  rc=$?
  if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q '^status: failed$'; then
    echo "ok   $opt"
  else
    echo "FAIL $opt: exit $rc (want 2), output: ${out:-<none>}"
    fail=1
  fi
done

exit "$fail"

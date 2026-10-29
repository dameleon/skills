#!/usr/bin/env bash
set -eu
cp -R "$(dirname "$0")/files/." .
mkdir -p bin && cp "$(dirname "$0")/../files/bin/gh" bin/gh && chmod +x bin/gh

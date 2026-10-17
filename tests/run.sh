#!/usr/bin/env bash
# Run headless tests. Usage: tests/run.sh [file_filter]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
out=$(perl -e 'alarm shift; exec @ARGV' "${TEST_TIMEOUT:-900}" "$GODOT" --headless --path . -s tests/run_tests.gd -- "${1:-}" 2>&1) && code=0 || code=$?
echo "$out" | grep -vE "^Godot Engine|^$"
if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
  echo "script errors detected"; exit 1
fi
exit $code

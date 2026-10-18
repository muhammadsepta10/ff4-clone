#!/usr/bin/env bash
# Parse/type-check every GDScript file headlessly. Exit 1 on any error.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
out=$(perl -e 'alarm 120; exec @ARGV' "$GODOT" --headless --path . -s tools/typecheck.gd 2>&1)
code=$?
echo "$out" | grep -E "SCRIPT ERROR|Parse Error|Compile Error|at: GDScript|FAIL|typecheck" | grep -v "Failed to compile depended"
exit $code

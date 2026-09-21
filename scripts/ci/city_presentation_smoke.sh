#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
test_profile="$(mktemp -d "${TMPDIR:-/tmp}/deadfall-city.XXXXXX")"
trap 'rm -rf "$test_profile"' EXIT
export XDG_DATA_HOME="$test_profile"
mkdir -p build/city-smoke
for test_name in city_visual_smoke operators_visual_smoke; do
  log_path="build/city-smoke/${test_name}.log"
  result=0
  timeout 80s "${GODOT_BIN:-godot}" --path . --rendering-method gl_compatibility \
    --audio-driver Dummy --script "scripts/ci/${test_name}.gd" >"$log_path" 2>&1 || result=$?
  cat "$log_path"
  (( result == 0 )) || exit "$result"
  if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Parse Error:|Compile Error:|^ERROR:' "$log_path"; then
    exit 1
  fi
  grep -q 'smoke passed' "$log_path"
done

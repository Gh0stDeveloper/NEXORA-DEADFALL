#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
test_profile="$(mktemp -d "${TMPDIR:-/tmp}/deadfall-social-ui.XXXXXX")"
trap 'rm -rf "$test_profile"' EXIT
export XDG_DATA_HOME="$test_profile"
export DEADFALL_PRESENTATION_TEST=1
mkdir -p build
result=0
timeout 90s "${GODOT_BIN:-godot}" --path . --rendering-method gl_compatibility \
  --audio-driver Dummy --script scripts/ci/social_ui_smoke.gd \
  >build/social-ui.log 2>&1 || result=$?
cat build/social-ui.log
if (( result != 0 )); then exit "$result"; fi
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Compile Error:|^ERROR:' build/social-ui.log; then exit 1; fi
grep -q 'NEXORA: DEADFALL rendered social and mode selection smoke passed' build/social-ui.log

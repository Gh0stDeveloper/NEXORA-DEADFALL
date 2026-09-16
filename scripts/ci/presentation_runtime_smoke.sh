#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# The fixture creates a real local guest account. Never use a player's profile.
test_profile="$(mktemp -d "${TMPDIR:-/tmp}/deadfall-presentation.XXXXXX")"
trap 'rm -rf "$test_profile"' EXIT
export XDG_DATA_HOME="$test_profile"
export DEADFALL_PRESENTATION_TEST=1
mkdir -p build
result=0
timeout 95s "${GODOT_BIN:-godot}" --path . --rendering-method gl_compatibility \
  --audio-driver Dummy --script scripts/ci/presentation_runtime_smoke.gd \
  >build/presentation-runtime.log 2>&1 || result=$?
cat build/presentation-runtime.log
if (( result != 0 )); then
  exit "$result"
fi
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Compile Error:|^ERROR:' build/presentation-runtime.log; then
  exit 1
fi
grep -q 'NEXORA: DEADFALL rendered presentation runtime smoke passed' build/presentation-runtime.log

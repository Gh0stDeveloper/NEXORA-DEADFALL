#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
DEADFALL_PORT="${DEADFALL_PORT:-24560}"

exec "$GODOT_BIN" --headless --path "$ROOT_DIR" -- --server "--port=${DEADFALL_PORT}"

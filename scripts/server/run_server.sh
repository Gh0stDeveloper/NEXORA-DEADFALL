#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
DEADFALL_PORT="${DEADFALL_PORT:-24560}"
DEADFALL_DIRECTORY_PORT="${DEADFALL_DIRECTORY_PORT:-24561}"
DEADFALL_PUBLIC_HOST="${DEADFALL_PUBLIC_HOST:-127.0.0.1}"
DEADFALL_ROOM_CODE="${DEADFALL_ROOM_CODE:-}"

exec "$GODOT_BIN" --headless --path "$ROOT_DIR" -- \
  --server \
  "--port=${DEADFALL_PORT}" \
  "--directory-port=${DEADFALL_DIRECTORY_PORT}" \
  "--public-host=${DEADFALL_PUBLIC_HOST}" \
  "--room=${DEADFALL_ROOM_CODE}"

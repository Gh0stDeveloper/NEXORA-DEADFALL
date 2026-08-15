#!/usr/bin/env bash
set -euo pipefail
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${DEADFALL_DUO_TEST_PORT:-24660}"
DIR_PORT="$((PORT + 1))"
ROOM="DUA2A9"
SERVER_LOG="/tmp/deadfall-duo-server.log"
CLIENT_A_LOG="/tmp/deadfall-duo-client-a.log"
CLIENT_B_LOG="/tmp/deadfall-duo-client-b.log"
cleanup() {
  [[ -n "${SERVER_PID:-}" ]] && kill "$SERVER_PID" >/dev/null 2>&1 || true
  [[ -n "${CLIENT_A_PID:-}" ]] && kill "$CLIENT_A_PID" >/dev/null 2>&1 || true
  [[ -n "${CLIENT_B_PID:-}" ]] && kill "$CLIENT_B_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT
"$GODOT_BIN" --headless --path . -- --server --port="$PORT" --directory-port="$DIR_PORT" --public-host=127.0.0.1 --room="$ROOM" >"$SERVER_LOG" 2>&1 & SERVER_PID=$!
sleep 2
"$GODOT_BIN" --headless --path . -- --connect="127.0.0.1:$PORT" --name=Alpha --network-smoke >"$CLIENT_A_LOG" 2>&1 & CLIENT_A_PID=$!
sleep 1
"$GODOT_BIN" --headless --path . -- --connect="127.0.0.1:$PORT" --name=Bravo --network-smoke >"$CLIENT_B_LOG" 2>&1 & CLIENT_B_PID=$!
for _attempt in $(seq 1 20); do
  if grep -q "DEADFALL_DUO_SNAPSHOT players=2" "$CLIENT_A_LOG" && grep -q "DEADFALL_DUO_SNAPSHOT players=2" "$CLIENT_B_LOG"; then break; fi
  sleep 0.5
done
grep -q "dedicated server listening on UDP $PORT" "$SERVER_LOG"
grep -q "DEADFALL_DUO_JOIN_ACCEPTED" "$CLIENT_A_LOG"
grep -q "DEADFALL_DUO_JOIN_ACCEPTED" "$CLIENT_B_LOG"
grep -q "DEADFALL_DUO_SNAPSHOT players=2" "$CLIENT_A_LOG"
grep -q "DEADFALL_DUO_SNAPSHOT players=2" "$CLIENT_B_LOG"
echo "NEXORA: DEADFALL duo integration smoke passed"

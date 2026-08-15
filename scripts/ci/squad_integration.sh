#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${DEADFALL_SQUAD_TEST_PORT:-24760}"
DIR_PORT="$((PORT + 1))"
ROOM="SQD4A9"
SERVER_LOG="/tmp/deadfall-squad-server.log"
CLIENT_A_LOG="/tmp/deadfall-squad-client-a.log"
CLIENT_B_LOG="/tmp/deadfall-squad-client-b.log"
CLIENT_C_LOG="/tmp/deadfall-squad-client-c.log"
CLIENT_D_LOG="/tmp/deadfall-squad-client-d.log"

cleanup() {
  for pid in "${SERVER_PID:-}" "${CLIENT_A_PID:-}" "${CLIENT_B_PID:-}" "${CLIENT_C_PID:-}" "${CLIENT_D_PID:-}"; do
    [[ -n "$pid" ]] && kill "$pid" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

"$GODOT_BIN" --headless --path . -- --server --port="$PORT" --directory-port="$DIR_PORT" --public-host=127.0.0.1 --room="$ROOM" >"$SERVER_LOG" 2>&1 & SERVER_PID=$!
sleep 2

"$GODOT_BIN" --headless --path . -- --connect="127.0.0.1:$PORT" --name=Alpha >"$CLIENT_A_LOG" 2>&1 & CLIENT_A_PID=$!
sleep 0.5
"$GODOT_BIN" --headless --path . -- --connect="127.0.0.1:$PORT" --name=Bravo >"$CLIENT_B_LOG" 2>&1 & CLIENT_B_PID=$!
sleep 0.5
"$GODOT_BIN" --headless --path . -- --connect="127.0.0.1:$PORT" --name=Charlie >"$CLIENT_C_LOG" 2>&1 & CLIENT_C_PID=$!
sleep 0.5
"$GODOT_BIN" --headless --path . -- --connect="127.0.0.1:$PORT" --name=Delta >"$CLIENT_D_LOG" 2>&1 & CLIENT_D_PID=$!

for _attempt in $(seq 1 30); do
  if grep -q "DEADFALL_SQUAD_SNAPSHOT players=4" "$CLIENT_A_LOG" \
    && grep -q "DEADFALL_SQUAD_SNAPSHOT players=4" "$CLIENT_B_LOG" \
    && grep -q "DEADFALL_SQUAD_SNAPSHOT players=4" "$CLIENT_C_LOG" \
    && grep -q "DEADFALL_SQUAD_SNAPSHOT players=4" "$CLIENT_D_LOG"; then
    break
  fi
  sleep 0.5
done

grep -q "dedicated server listening on UDP $PORT" "$SERVER_LOG"
grep -q "DEADFALL_SQUAD_ROOM" "$SERVER_LOG"
for log in "$CLIENT_A_LOG" "$CLIENT_B_LOG" "$CLIENT_C_LOG" "$CLIENT_D_LOG"; do
  grep -q "DEADFALL_SQUAD_JOIN_ACCEPTED" "$log"
  grep -q "DEADFALL_SQUAD_SNAPSHOT players=4" "$log"
done

JOIN_COUNT="$(grep -c "DEADFALL_SQUAD_SERVER_JOIN" "$SERVER_LOG" || true)"
if [[ "$JOIN_COUNT" -ne 4 ]]; then
  echo "Expected exactly four Squad joins, got $JOIN_COUNT" >&2
  cat "$SERVER_LOG" >&2
  exit 1
fi

echo "NEXORA: DEADFALL four-peer Squad integration smoke passed"

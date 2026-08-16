#!/usr/bin/env bash
set -euo pipefail
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${DEADFALL_CAMPAIGN_TEST_PORT:-24860}"
DIR_PORT="$((PORT + 1))"
ROOM="CAM8P2"
MISSION="mission_01_first_signal"
SERVER_LOG="/tmp/deadfall-campaign-server.log"
CLIENT_LOGS=()
PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do kill "$pid" >/dev/null 2>&1 || true; done
}
trap cleanup EXIT

"$GODOT_BIN" --headless --path . -- --server --campaign --mission="$MISSION" --port="$PORT" --directory-port="$DIR_PORT" --public-host=127.0.0.1 --room="$ROOM" >"$SERVER_LOG" 2>&1 &
PIDS+=("$!")
sleep 2

names=(Alpha Bravo Charlie Delta)
for index in "${!names[@]}"; do
  log="/tmp/deadfall-campaign-client-$index.log"
  CLIENT_LOGS+=("$log")
  "$GODOT_BIN" --headless --path . -- --connect="127.0.0.1:$PORT" --campaign --mission="$MISSION" --name="${names[$index]}" --network-smoke >"$log" 2>&1 &
  PIDS+=("$!")
  sleep 0.5
done

for _attempt in $(seq 1 30); do
  ready=1
  for log in "${CLIENT_LOGS[@]}"; do
    grep -q "DEADFALL_SQUAD_SNAPSHOT players=4" "$log" || ready=0
    grep -q "DEADFALL_CAMPAIGN_SNAPSHOT mission=$MISSION" "$log" || ready=0
  done
  [[ "$ready" -eq 1 ]] && break
  sleep 0.5
done

grep -q "dedicated server listening on UDP $PORT" "$SERVER_LOG"
grep -q "DEADFALL_CAMPAIGN_SERVER mission=$MISSION" "$SERVER_LOG"
for log in "${CLIENT_LOGS[@]}"; do
  grep -q "DEADFALL_SQUAD_JOIN_ACCEPTED" "$log"
  grep -q "DEADFALL_SQUAD_SNAPSHOT players=4" "$log"
  grep -q "DEADFALL_CAMPAIGN_SNAPSHOT mission=$MISSION" "$log"
done

echo "NEXORA: DEADFALL campaign four-peer integration smoke passed"

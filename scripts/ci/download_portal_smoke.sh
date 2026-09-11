#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SITE="$ROOT/web/download-site"
TMP_DIR="$(mktemp -d)"
SERVER_PID=""
SITE_RUNNER_USER=deadfall
run_site(){
  if [[ "$(id -u)" -eq 0 ]] && id "$SITE_RUNNER_USER" >/dev/null 2>&1; then
    sudo -H -u "$SITE_RUNNER_USER" -- "$@"
  else
    "$@"
  fi
}
cleanup(){
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

python3 "$SITE/scripts/publish_release_history.py"   --source "$SITE/src/data/releases.json"   --output "$TMP_DIR/releases.json"

python3 - "$TMP_DIR/releases.json" <<'PY'
import json
import re
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["schema_version"] == 1
current = data["current"]
matches = [item for item in data["releases"] if item["version"] == current]
assert len(matches) == 1
assert matches[0]["status"] == "current"
assert matches[0]["download"] == "/downloads/NEXORA-DEADFALL-latest.apk"
assert any(item["status"] == "superseded" for item in data["releases"])
assert all(item["status"] in {"current", "superseded", "withdrawn"} for item in data["releases"])
for item in data["releases"]:
    assert len(item["added"]) + len(item["changed"]) + len(item["fixed"]) > 0
    if item["sha256"] is not None:
        assert re.fullmatch(r"[0-9a-f]{64}", item["sha256"], re.I)
print("NEXORA: release history schema smoke passed")
PY

cd "$SITE"
run_site npm install --package-lock=false --no-audit --no-fund
run_site npm run build
test -s .next/standalone/server.js

if [[ -z "${PORTAL_PORT:-}" ]]; then PORTAL_PORT=3199; fi
run_site npm run start -- --hostname 127.0.0.1 --port "$PORTAL_PORT" >"$TMP_DIR/portal.log" 2>&1 &
SERVER_PID="$!"
for _attempt in $(seq 1 30); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$PORTAL_PORT/" >/dev/null; then
    break
  fi
  sleep 1
done
curl -fsS "http://127.0.0.1:$PORTAL_PORT/" | grep -Fq "DEADFALL."
curl -fsS "http://127.0.0.1:$PORTAL_PORT/versiones" | grep -Fq "Historial de versiones."
curl -fsS "http://127.0.0.1:$PORTAL_PORT/releases.json" | jq -e '.schema_version == 1 and .current == "0.9.0-beta.5"' >/dev/null
curl -fsS "http://127.0.0.1:$PORTAL_PORT/versiones/0.9.0-beta.5" | grep -Fq "Integridad del archivo"
if ! curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORTAL_PORT/versiones/no-existe" | grep -Fxq "404"; then
  echo "Portal no devolvió 404 para una versión inexistente" >&2
  exit 1
fi
echo "NEXORA: DEADFALL download portal smoke passed"

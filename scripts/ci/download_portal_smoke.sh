#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SITE="$ROOT/web/download-site"
TMP_DIR="$(mktemp -d)"
SERVER_PID=""
SITE_RUNNER=()
if [[ "$(id -u)" -eq 0 ]] && id deadfall >/dev/null 2>&1; then
  SITE_RUNNER=(sudo -H -u deadfall --)
fi
die(){ printf '%s\n' "$*" >&2; exit 1; }
source "$ROOT/deploy/vps/lib/portal.sh"
cleanup(){
  local status=$?
  if [[ "$status" -ne 0 && -f "$TMP_DIR/portal.log" ]]; then
    tail -n 80 "$TMP_DIR/portal.log" >&2
  fi
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
  return "$status"
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
if matches[0]["download_available"]:
    assert matches[0]["download"] == "/downloads/NEXORA-DEADFALL-latest.apk"
else:
    assert matches[0]["download"] is None
assert any(item["status"] == "superseded" for item in data["releases"])
assert all(item["status"] in {"current", "superseded", "withdrawn"} for item in data["releases"])
for item in data["releases"]:
    assert len(item["added"]) + len(item["changed"]) + len(item["fixed"]) > 0
    if item["sha256"] is not None:
        assert re.fullmatch(r"[0-9a-f]{64}", item["sha256"], re.I)
print("NEXORA: release history schema smoke passed")
PY

# The updater builds the portal before Android. Keep the existing signed APK
# and matching version visible, then advance atomically after the APK export.
python3 - "$SITE/scripts/publish_release_history.py" "$SITE/src/data/releases.json" "$TMP_DIR" <<'PY'
import json, subprocess, sys
from pathlib import Path
publisher, source, temporary = sys.argv[1:]
root = Path(temporary)
catalog = json.loads(Path(source).read_text())
previous = next(item for item in catalog['releases'] if item['status'] == 'superseded')
manifest = {'version': previous['version'], 'bytes': 123456, 'sha256': 'b' * 64,
            'git_sha': 'c' * 40, 'published_unix': 1789588800,
            'download': '/downloads/NEXORA-DEADFALL-latest.apk'}
manifest_path, history_path = root / 'upgrade-release.json', root / 'upgrade-history.json'
manifest_path.write_text(json.dumps(manifest))
command = [sys.executable, publisher, '--source', source, '--current', str(manifest_path), '--output', str(history_path)]
strict = subprocess.run(command, capture_output=True, text=True)
assert strict.returncode != 0, 'Final APK publisher must reject a mismatched manifest'
subprocess.run([*command, '--keep-published-version'], check=True)
history = json.loads(history_path.read_text())
assert history['current'] == previous['version']
assert all(item['version'] != catalog['current'] for item in history['releases'])
published = next(item for item in history['releases'] if item['status'] == 'current')
assert published['download_available'] and published['sha256'] == 'b' * 64
manifest.update(version=catalog['current'], sha256='a' * 64)
manifest_path.write_text(json.dumps(manifest))
subprocess.run(command, check=True)
history = json.loads(history_path.read_text())
assert history['current'] == catalog['current']
published = next(item for item in history['releases'] if item['status'] == 'current')
assert published['download_available'] and published['sha256'] == 'a' * 64
print('NEXORA: release upgrade publication smoke passed')
PY

cd "$SITE"
"${SITE_RUNNER[@]}" npm install --package-lock=false --no-audit --no-fund
"${SITE_RUNNER[@]}" npm run build
test -s .next/standalone/server.js

# Exercise the copied standalone artifact that systemd serves on the VPS.
cp -a .next/standalone "$TMP_DIR/site"
mkdir -p "$TMP_DIR/site/.next"
cp -a .next/static "$TMP_DIR/site/.next/static"
[[ ! -d public ]] || cp -a public "$TMP_DIR/site/public"
chmod 0755 "$TMP_DIR"

DEADFALL_PUBLIC_DIR="$TMP_DIR"
CURRENT_VERSION="$(jq -r .current "$TMP_DIR/releases.json")"
BASE_URL="http://127.0.0.1:${PORTAL_PORT:-3199}"
(
  cd "$TMP_DIR/site"
  exec "${SITE_RUNNER[@]}" env HOSTNAME=127.0.0.1 PORT="${PORTAL_PORT:-3199}" \
    DEADFALL_RELEASE_HISTORY="$TMP_DIR/releases.json" node server.js
) >"$TMP_DIR/portal.log" 2>&1 &
SERVER_PID="$!"
PORTAL_READY=0
for _attempt in $(seq 1 30); do
  if curl -fsS --max-time 2 "$BASE_URL/" >"$TMP_DIR/home.html" 2>/dev/null; then
    PORTAL_READY=1
    break
  fi
  kill -0 "$SERVER_PID" 2>/dev/null || die "El servidor standalone terminó antes de estar listo."
  sleep 1
done
[[ "$PORTAL_READY" -eq 1 ]] || die "El servidor standalone no respondió dentro del plazo."
validate_portal_routes "$BASE_URL"
for path in /compatibilidad /beta /favicon.svg; do
  curl -fsS --max-time 5 "$BASE_URL$path" >/dev/null
done
for suffix in "" "/$CURRENT_VERSION"; do
  redirect="$(curl -sS --max-time 5 -o /dev/null -w '%{http_code} %{redirect_url}' "$BASE_URL/versions$suffix")"
  [[ "$redirect" == "308 $BASE_URL/versiones$suffix" ]] || die "Redirección antigua inválida: $redirect"
done
CSS_PATH="$(python3 - "$TMP_DIR/home.html" <<'PY'
import re, sys
from pathlib import Path
match = re.search(r'href="([^"\s]*/_next/static/[^"\s]+\.css)"', Path(sys.argv[1]).read_text())
assert match, "El HTML no enlaza una hoja de estilos del build"
print(match.group(1))
PY
)"
curl -fsS --max-time 5 "$BASE_URL$CSS_PATH" >/dev/null

# Publishing another APK must change the live catalog without rebuilding or
# restarting Next.js, even when the runtime file was absent at build time.
python3 - "$TMP_DIR" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
catalog = json.loads((root / 'releases.json').read_text())
current = next(r for r in catalog['releases'] if r['version'] == catalog['current'])
current.update(summary='Runtime publication fixture', sha256='a' * 64, bytes=123456)
pending = root / 'releases.pending.json'
pending.write_text(json.dumps(catalog))
pending.replace(root / 'releases.json')
(root / 'release.json').write_text(json.dumps({'sha256': current['sha256']}))
PY
validate_portal_routes "$BASE_URL"
portal_expect_text "$BASE_URL/versiones/$CURRENT_VERSION" 'Runtime publication fixture'
curl -fsS --max-time 5 "$BASE_URL/releases.json" |
  jq -e --arg current "$CURRENT_VERSION" '.releases[] | select(.version == $current) | .bytes == 123456 and .summary == "Runtime publication fixture"' >/dev/null
echo "NEXORA: DEADFALL download portal smoke passed"

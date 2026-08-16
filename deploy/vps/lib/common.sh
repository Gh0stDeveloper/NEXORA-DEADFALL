#!/usr/bin/env bash
set -euo pipefail

DEADFALL_USER="${DEADFALL_USER:-deadfall}"
DEADFALL_GROUP="${DEADFALL_GROUP:-deadfall}"
DEADFALL_HOME="${DEADFALL_HOME:-/var/lib/nexora-deadfall}"
DEADFALL_ROOT="${DEADFALL_ROOT:-/opt/nexora-deadfall}"
DEADFALL_ETC="${DEADFALL_ETC:-/etc/nexora-deadfall}"
DEADFALL_ENV="${DEADFALL_ENV:-$DEADFALL_ETC/nexora-deadfall.env}"
DEADFALL_STATE="${DEADFALL_STATE:-$DEADFALL_HOME/install-state.json}"
DEADFALL_PUBLIC_DIR="${DEADFALL_PUBLIC_DIR:-/var/www/nexora-deadfall}"
DEADFALL_DOWNLOAD_DIR="${DEADFALL_DOWNLOAD_DIR:-$DEADFALL_PUBLIC_DIR/downloads}"
DEADFALL_BUILD_DIR="${DEADFALL_BUILD_DIR:-$DEADFALL_HOME/builds}"
DEADFALL_LOG_DIR="${DEADFALL_LOG_DIR:-/var/log/nexora-deadfall}"
DEADFALL_KEYSTORE="${DEADFALL_KEYSTORE:-$DEADFALL_ETC/signing/deadfall-release.keystore}"
DEADFALL_KEYSTORE_META="${DEADFALL_KEYSTORE_META:-$DEADFALL_ETC/signing/keystore.env}"

log(){ printf '\033[1;36m[DEADFALL]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }
require_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Ejecuta este comando como root o con sudo."; }
load_env(){ [[ -f "$DEADFALL_ENV" ]] && set -a && source "$DEADFALL_ENV" && set +a || true; }
run_deadfall(){ sudo -H -u "$DEADFALL_USER" -- "$@"; }
# Use this for bootstrap commands that may be launched while root's current
# directory is under /root. The service account cannot stat/traverse that CWD,
# so force a safe working directory before executing gh/git.
run_deadfall_home(){
  sudo -H -u "$DEADFALL_USER" -- bash -c 'cd "$HOME" && exec "$@"' bash "$@"
}
ensure_dirs(){
  install -d -m 0755 "$DEADFALL_HOME" "$DEADFALL_BUILD_DIR" "$DEADFALL_PUBLIC_DIR" "$DEADFALL_DOWNLOAD_DIR" "$DEADFALL_LOG_DIR"
  install -d -m 0750 "$DEADFALL_ETC" "$DEADFALL_ETC/signing"
  chown -R "$DEADFALL_USER:$DEADFALL_GROUP" "$DEADFALL_HOME" "$DEADFALL_LOG_DIR"
  chown -R www-data:www-data "$DEADFALL_PUBLIC_DIR"
}
json_state(){
  python3 - "$DEADFALL_STATE" "$@" <<'PY'
import json, pathlib, sys, time
p=pathlib.Path(sys.argv[1]); data={}
if p.exists():
    try:data=json.loads(p.read_text())
    except Exception:data={}
for arg in sys.argv[2:]:
    k,v=arg.split('=',1); data[k]=v
data['updated_unix']=int(time.time())
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text(json.dumps(data,indent=2)+'\n')
PY
  chown "$DEADFALL_USER:$DEADFALL_GROUP" "$DEADFALL_STATE" 2>/dev/null || true
}

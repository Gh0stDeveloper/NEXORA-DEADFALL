#!/usr/bin/env bash
set -euo pipefail
ROOT_FALLBACK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_FALLBACK/deploy/vps/lib/common.sh"
require_root
load_env

INITIAL=0
FORCE=0
[[ "${1:-}" == "--initial" ]] && INITIAL=1
[[ "${1:-}" == "--force" ]] && FORCE=1
[[ -d "$DEADFALL_ROOT/.git" ]] || die "Repositorio no instalado: $DEADFALL_ROOT"
run_deadfall_home gh auth status --hostname github.com >/dev/null 2>&1 || die "GitHub auth inválida. Ejecuta: nexora-deadfall auth"
run_deadfall_home git -C "$DEADFALL_ROOT" fetch --prune origin "$DEADFALL_BRANCH"
OLD="$(run_deadfall_home git -C "$DEADFALL_ROOT" rev-parse HEAD)"
NEW="$(run_deadfall_home git -C "$DEADFALL_ROOT" rev-parse "origin/$DEADFALL_BRANCH")"

if [[ "$INITIAL" -eq 1 || "$FORCE" -eq 1 ]]; then
  CHANGED="ALL"
elif [[ "$OLD" == "$NEW" ]]; then
  log "Sin actualizaciones ($OLD)."
  exit 0
else
  CHANGED="$(run_deadfall_home git -C "$DEADFALL_ROOT" diff --name-only "$OLD..$NEW")"
fi

run_deadfall_home git -C "$DEADFALL_ROOT" reset --hard "$NEW"
APP=0; SERVER=0; WEB=0; DEPLOY=0
if [[ "$CHANGED" == "ALL" ]]; then
  APP=1; SERVER=1; WEB=1; DEPLOY=1
else
  grep -Eq '^(project\.godot|export_presets\.cfg|src/|assets/|android/)' <<<"$CHANGED" && { APP=1; SERVER=1; }
  grep -Eq '^(src/(server|network|core|horde|zombies|campaign)/|scripts/server/)' <<<"$CHANGED" && SERVER=1
  grep -Eq '^web/download-site/' <<<"$CHANGED" && WEB=1
  grep -Eq '^(deploy/(systemd|vps|nginx)/|scripts/build/)' <<<"$CHANGED" && { DEPLOY=1; SERVER=1; WEB=1; }
fi
log "Cambios detectados: app=$APP server=$SERVER web=$WEB deploy=$DEPLOY"

if [[ "$DEPLOY" -eq 1 ]]; then
  install -m 0755 "$DEADFALL_ROOT/deploy/vps/nexora-deadfall" /usr/local/bin/nexora-deadfall
  cp "$DEADFALL_ROOT/deploy/systemd/nexora-deadfall.service" /etc/systemd/system/nexora-deadfall.service
  cp "$DEADFALL_ROOT/deploy/systemd/nexora-deadfall-download.service" /etc/systemd/system/nexora-deadfall-download.service
  configure_nginx_site "$DEADFALL_ROOT/deploy/nginx/nexora-deadfall.conf.template" "${DEADFALL_DOMAIN:-_}"
  systemctl daemon-reload
  systemctl reload nginx
fi

if [[ "$APP" -eq 1 || "$SERVER" -eq 1 ]]; then
  run_deadfall godot --headless --editor --path "$DEADFALL_ROOT" --quit
  run_deadfall godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/smoke.gd
  run_deadfall godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/beta_hardening_smoke.gd
fi
if [[ "$APP" -eq 1 ]]; then "$DEADFALL_ROOT/scripts/build/build_android_vps.sh"; fi
if [[ "$WEB" -eq 1 || "$APP" -eq 1 ]]; then "$DEADFALL_ROOT/scripts/build/build_download_site.sh"; fi
if [[ "$SERVER" -eq 1 ]]; then systemctl restart nexora-deadfall; fi
if [[ "$WEB" -eq 1 || "$APP" -eq 1 ]]; then systemctl restart nexora-deadfall-download; fi

json_state "last_deployed_sha=$NEW" "last_app_rebuild=$APP" "last_server_restart=$SERVER" "last_web_rebuild=$WEB"
log "Actualización completada: $NEW"

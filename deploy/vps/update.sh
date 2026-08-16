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
DEPLOYED=""
if [[ -f "$DEADFALL_STATE" ]]; then
  DEPLOYED="$(jq -r '.last_deployed_sha // empty' "$DEADFALL_STATE" 2>/dev/null || true)"
fi

mark_failed_attempt(){
  local status=$?
  if [[ "$status" -ne 0 ]]; then
    json_state "last_attempted_sha=$NEW" "last_deploy_status=failed"
    warn "El despliegue de $NEW no terminó. El próximo 'nexora-deadfall update' volverá a ejecutar los gates/builds."
  fi
  return "$status"
}
trap mark_failed_attempt EXIT

if [[ "$INITIAL" -eq 1 || "$FORCE" -eq 1 ]]; then
  CHANGED="ALL"
elif [[ -z "$DEPLOYED" ]]; then
  warn "No existe un last_deployed_sha exitoso; se repetirá un despliegue completo."
  CHANGED="ALL"
elif [[ "$DEPLOYED" == "$NEW" ]]; then
  if [[ "$OLD" != "$NEW" ]]; then
    run_deadfall_home git -C "$DEADFALL_ROOT" reset --hard "$NEW"
  fi
  log "Sin actualizaciones desplegables ($NEW)."
  trap - EXIT
  exit 0
elif run_deadfall_home git -C "$DEADFALL_ROOT" cat-file -e "${DEPLOYED}^{commit}" 2>/dev/null; then
  CHANGED="$(run_deadfall_home git -C "$DEADFALL_ROOT" diff --name-only "$DEPLOYED..$NEW")"
else
  warn "El último SHA desplegado ($DEPLOYED) no está disponible localmente; se hará despliegue completo."
  CHANGED="ALL"
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
  # Global named-class metadata is generated state. Removing only this cache
  # prevents a failed previous import from pinning stale class_name entries.
  rm -f "$DEADFALL_ROOT/.godot/global_script_class_cache.cfg"
  run_deadfall_home godot --headless --editor --path "$DEADFALL_ROOT" --quit
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/smoke.gd
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/beta_hardening_smoke.gd
fi
if [[ "$APP" -eq 1 ]]; then "$DEADFALL_ROOT/scripts/build/build_android_vps.sh"; fi
if [[ "$WEB" -eq 1 || "$APP" -eq 1 ]]; then "$DEADFALL_ROOT/scripts/build/build_download_site.sh"; fi
if [[ "$SERVER" -eq 1 ]]; then systemctl restart nexora-deadfall; fi
if [[ "$WEB" -eq 1 || "$APP" -eq 1 ]]; then systemctl restart nexora-deadfall-download; fi

json_state \
  "last_deployed_sha=$NEW" \
  "last_attempted_sha=$NEW" \
  "last_deploy_status=success" \
  "last_app_rebuild=$APP" \
  "last_server_restart=$SERVER" \
  "last_web_rebuild=$WEB"
trap - EXIT
log "Actualización completada: $NEW"

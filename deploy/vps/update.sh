#!/usr/bin/env bash
set -euo pipefail
ROOT_FALLBACK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_FALLBACK/deploy/vps/lib/common.sh"
source "$ROOT_FALLBACK/deploy/vps/lib/portal.sh"
require_root
load_env
ORIGINAL_ARGS=("$@")

INITIAL=0
FORCE=0
TESTS_ONLY=0
NETWORK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --initial) INITIAL=1;;
    --force) FORCE=1;;
    --tests-only) TESTS_ONLY=1;;
    --network-only) NETWORK_ONLY=1;;
    *) die "Opción desconocida: $arg. Usa --initial, --force, --tests-only o --network-only.";;
  esac
done
[[ "$TESTS_ONLY" -eq 1 && "$NETWORK_ONLY" -eq 1 ]] && die "Usa --tests-only o --network-only, no ambos a la vez."
VALIDATION_ONLY=0
[[ "$TESTS_ONLY" -eq 1 || "$NETWORK_ONLY" -eq 1 ]] && VALIDATION_ONLY=1

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
    if [[ "$VALIDATION_ONLY" -eq 1 ]]; then
      warn "La validación de $NEW falló. No se cambió el estado del último despliegue exitoso."
    else
      json_state "last_attempted_sha=$NEW" "last_deploy_status=failed"
      warn "El despliegue de $NEW no terminó. El próximo 'nexora-deadfall update' volverá a ejecutar los gates/builds."
    fi
  fi
  return "$status"
}
trap mark_failed_attempt EXIT

if [[ "$VALIDATION_ONLY" -eq 1 ]]; then
  CHANGED="VALIDATION"
elif [[ "$INITIAL" -eq 1 || "$FORCE" -eq 1 ]]; then
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
if [[ "${DEADFALL_UPDATE_REEXEC:-0}" != "1" && "$OLD" != "$NEW" ]]; then
  if ! run_deadfall_home git -C "$DEADFALL_ROOT" diff --quiet "$OLD" "$NEW" -- deploy/vps/update.sh; then
    log "El updater cambió en $NEW; reejecutando la versión nueva antes de continuar..."
    trap - EXIT
    exec env DEADFALL_UPDATE_REEXEC=1 bash "$DEADFALL_ROOT/deploy/vps/update.sh" "${ORIGINAL_ARGS[@]}"
  fi
fi

prepare_validation_project(){
  log "Preparando modelos 3D y caché Godot para validación..."
  run_deadfall_home git -C "$DEADFALL_ROOT" submodule sync -- vendor/Objetos3D >/dev/null 2>&1 || true
  run_deadfall_home git -C "$DEADFALL_ROOT" submodule update --init --recursive --depth 1 vendor/Objetos3D || \
    warn "No se pudo inicializar el submódulo directamente; sync_objetos3d.sh intentará el fallback autenticado."
  run_deadfall_home bash "$DEADFALL_ROOT/scripts/assets/sync_objetos3d.sh" "$DEADFALL_ROOT"
  rm -f "$DEADFALL_ROOT/.godot/global_script_class_cache.cfg"
  run_deadfall_home godot --headless --editor --path "$DEADFALL_ROOT" --quit
}

run_strict_gameplay_compile_gate(){
  log "Validando compilación estricta de gameplay/HUD/loadout/ciclo día-noche..."
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/gameplay_compile_smoke.gd
}

run_android_template_patch_gate(){
  log "Validando sanitización reproducible del template Android/Manifest Merger..."
  bash "$DEADFALL_ROOT/scripts/ci/android_template_patch_smoke.sh"
}
if [[ "$NETWORK_ONLY" -eq 1 ]]; then
  prepare_validation_project
  run_strict_gameplay_compile_gate
  log "Validando transporte MTU-safe y escena Campaign antes de los probes reales..."
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/phase11_network_transport_smoke.gd
  log "Ejecutando únicamente el smoke real de red/orquestación/tickets de Phase 11.3..."
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/phase11_orchestration_smoke.gd
  trap - EXIT
  log "Validación de red Phase 11.3 completada: $NEW (sin portal, APK ni cambio de estado de despliegue)."
  exit 0
fi

if [[ "$TESTS_ONLY" -eq 1 ]]; then
  prepare_validation_project
  log "Ejecutando gates Godot/Closed Beta/Phase 11.3 sin compilar ni desplegar artefactos..."
  run_android_template_patch_gate
  run_strict_gameplay_compile_gate
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/smoke.gd
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/beta_hardening_smoke.gd
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/phase11_smoke.gd
  bash "$DEADFALL_ROOT/scripts/ci/download_portal_smoke.sh"
  trap - EXIT
  log "Gates de validación completados: $NEW (sin portal, APK ni cambio de estado de despliegue)."
  exit 0
fi

APP=0; SERVER=0; WEB=0; DEPLOY=0
if [[ "$CHANGED" == "ALL" ]]; then
  APP=1; SERVER=1; WEB=1; DEPLOY=1
else
  grep -Eq '^(project\.godot|export_presets\.cfg|\.gitmodules$|vendor/Objetos3D($|/)|src/|assets/|android/|scripts/assets/)' <<<"$CHANGED" && { APP=1; SERVER=1; }
  grep -Eq '^(src/(server|network|core|horde|zombies|campaign|identity|lobby|social|login|assets|player)/|scripts/server/)' <<<"$CHANGED" && SERVER=1
  grep -Eq '^web/download-site/' <<<"$CHANGED" && WEB=1
  grep -Eq '^deploy/(systemd|vps|nginx)/' <<<"$CHANGED" && { DEPLOY=1; APP=1; SERVER=1; WEB=1; }
  grep -Eq '^scripts/build/(build_android_vps\.sh|patch_android_template\.py|deadfall_android_init\.gradle)$' <<<"$CHANGED" && { APP=1; SERVER=1; }
  grep -Eq '^scripts/build/build_download_site\.sh$' <<<"$CHANGED" && WEB=1
fi
log "Cambios detectados: app=$APP server=$SERVER web=$WEB deploy=$DEPLOY"

if [[ "$DEPLOY" -eq 1 ]]; then
  install -m 0755 "$DEADFALL_ROOT/deploy/vps/nexora-deadfall" /usr/local/bin/nexora-deadfall
  cp "$DEADFALL_ROOT/deploy/systemd/nexora-deadfall.service" /etc/systemd/system/nexora-deadfall.service
  cp "$DEADFALL_ROOT/deploy/systemd/nexora-deadfall-download.service" /etc/systemd/system/nexora-deadfall-download.service
  configure_nginx_site "$DEADFALL_ROOT/deploy/nginx/nexora-deadfall.conf.template" "${DEADFALL_DOMAIN:-_}"
  ufw allow 24600:24749/udp >/dev/null
  ufw show added | grep -Fq 'ufw allow 24600:24749/udp' || \
    die "UFW no registró la regla UDP 24600:24749 requerida por MatchOrchestrator."
  if ufw status | grep -Eq '^Status: active'; then
    ufw status | grep -Eq '24600:24749/udp[[:space:]]+ALLOW' || \
      die "UFW está activo pero UDP 24600:24749 no aparece como ALLOW."
    log "UFW activo: rango dinámico UDP 24600:24749 verificado como ALLOW."
  else
    warn "UFW está inactivo. La regla UDP 24600:24749 quedó registrada, pero la Security List/NSG de Oracle sigue siendo un gate externo obligatorio."
  fi
  systemctl daemon-reload
  systemctl reload nginx
fi

if [[ "$APP" -eq 1 || "$SERVER" -eq 1 ]]; then
  log "Preparando modelos 3D vendorizados desde vendor/Objetos3D..."
  run_deadfall_home git -C "$DEADFALL_ROOT" submodule sync -- vendor/Objetos3D >/dev/null 2>&1 || true
  run_deadfall_home git -C "$DEADFALL_ROOT" submodule update --init --recursive --depth 1 vendor/Objetos3D || \
    warn "No se pudo inicializar el submódulo directamente; sync_objetos3d.sh intentará el fallback autenticado."
  run_deadfall_home bash "$DEADFALL_ROOT/scripts/assets/sync_objetos3d.sh" "$DEADFALL_ROOT"
  rm -f "$DEADFALL_ROOT/.godot/global_script_class_cache.cfg"
  log "Importando y validando GDScript en contexto completo del proyecto..."
  run_deadfall_home godot --headless --editor --path "$DEADFALL_ROOT" --quit
  if [[ "$APP" -eq 1 ]]; then
    run_android_template_patch_gate
  fi
  run_strict_gameplay_compile_gate
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/smoke.gd
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/beta_hardening_smoke.gd
  run_deadfall_home godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/phase11_smoke.gd
fi

if [[ "$WEB" -eq 1 || "$APP" -eq 1 ]]; then
  "$DEADFALL_ROOT/scripts/build/build_download_site.sh"
  systemctl restart nexora-deadfall-download
  PORTAL_OK=0
  for _attempt in $(seq 1 20); do
    if curl -fsS --max-time 3 http://127.0.0.1:3100/ >/dev/null 2>&1; then
      PORTAL_OK=1
      break
    fi
    sleep 1
  done
  [[ "$PORTAL_OK" -eq 1 ]] || die "El portal Next.js no responde en 127.0.0.1:3100. Revisa: journalctl -u nexora-deadfall-download -n 100 --no-pager"
  validate_portal_routes "http://127.0.0.1:3100"

  if [[ -n "${DEADFALL_DOMAIN:-}" && "${DEADFALL_DOMAIN:-}" != "_" ]]; then
    CERT="/etc/letsencrypt/live/$DEADFALL_DOMAIN/fullchain.pem"
    if [[ -f "$CERT" ]]; then
      curl -kfsS --max-time 8 --resolve "$DEADFALL_DOMAIN:443:127.0.0.1" "https://$DEADFALL_DOMAIN/" >/dev/null || \
        die "Nginx HTTPS no está sirviendo DEADFALL para $DEADFALL_DOMAIN. Revisa el vhost 443 activo."
      PUBLIC_CURRENT_VERSION="$(jq -r '.current // empty' "$DEADFALL_PUBLIC_DIR/releases.json")"
      curl -kfsS --max-time 8 --resolve "$DEADFALL_DOMAIN:443:127.0.0.1" "https://$DEADFALL_DOMAIN/releases.json" |         jq -e --arg current "$PUBLIC_CURRENT_VERSION" '.schema_version == 1 and .current == $current and ([.releases[] | select(.version == $current)] | length) == 1' >/dev/null ||         die "Nginx HTTPS no está publicando un historial válido."
      PUBLIC_DETAIL="$(curl -kfsS --max-time 8 --resolve "$DEADFALL_DOMAIN:443:127.0.0.1" "https://$DEADFALL_DOMAIN/versiones/$PUBLIC_CURRENT_VERSION")" || die "La ficha current no está disponible detrás de HTTPS."
      grep -Fq "Integridad del archivo" <<<"$PUBLIC_DETAIL" || die "La ficha current no contiene la información de integridad detrás de HTTPS."
      if ! curl -fsS --max-time 5 -H "Host: $DEADFALL_DOMAIN" http://127.0.0.1/ >/dev/null; then
        warn "El puerto HTTP/80 local no pertenece a DEADFALL (puede estar ocupado por otro servicio). HTTPS está correcto y será la ruta pública prioritaria."
      fi
      log "Portal Next.js validado en localhost y HTTPS para $DEADFALL_DOMAIN."
    else
      curl -fsS --max-time 5 -H "Host: $DEADFALL_DOMAIN" http://127.0.0.1/ >/dev/null || \
        die "Nginx no está sirviendo el portal por HTTP y todavía no existe certificado TLS para $DEADFALL_DOMAIN."
      log "Portal Next.js validado en localhost y HTTP para $DEADFALL_DOMAIN."
    fi
  else
    log "Portal Next.js validado en localhost."
  fi
fi

if [[ "$APP" -eq 1 ]]; then
  "$DEADFALL_ROOT/scripts/build/build_android_vps.sh"
fi
if [[ "$WEB" -eq 1 || "$APP" -eq 1 ]]; then
  validate_portal_routes "http://127.0.0.1:3100"
fi
if [[ "$SERVER" -eq 1 ]]; then
  systemctl restart nexora-deadfall
  CONTROL_OK=0
  for _attempt in $(seq 1 20); do
    if curl -fsS --max-time 3 http://127.0.0.1:24562/v1/health | jq -e '.ok == true' >/dev/null 2>&1; then
      CONTROL_OK=1
      break
    fi
    sleep 1
  done
  [[ "$CONTROL_OK" -eq 1 ]] || die "La API social DEADFALL no responde en 127.0.0.1:24562. Revisa: journalctl -u nexora-deadfall -n 150 --no-pager"
  log "API social/match DEADFALL validada en localhost:24562."

  if [[ -n "${DEADFALL_DOMAIN:-}" && "${DEADFALL_DOMAIN:-}" != "_" ]]; then
    CERT="/etc/letsencrypt/live/$DEADFALL_DOMAIN/fullchain.pem"
    if [[ -f "$CERT" ]]; then
      curl -kfsS --max-time 8 --resolve "$DEADFALL_DOMAIN:443:127.0.0.1" "https://$DEADFALL_DOMAIN/api/deadfall/v1/health" | jq -e '.ok == true' >/dev/null || \
        die "Nginx HTTPS no está publicando /api/deadfall/v1/health."
      log "API social/match DEADFALL validada detrás de HTTPS."
    fi
  fi
fi

json_state \
  "last_deployed_sha=$NEW" \
  "last_attempted_sha=$NEW" \
  "last_deploy_status=success" \
  "last_app_rebuild=$APP" \
  "last_server_restart=$SERVER" \
  "last_web_rebuild=$WEB"
trap - EXIT
log "Actualización completada: $NEW"

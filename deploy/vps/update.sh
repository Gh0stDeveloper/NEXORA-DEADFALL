#!/usr/bin/env bash
set -euo pipefail
ROOT_FALLBACK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; source "$ROOT_FALLBACK/deploy/vps/lib/common.sh"; require_root; load_env
INITIAL=0; FORCE=0; [[ "${1:-}" == "--initial" ]] && INITIAL=1; [[ "${1:-}" == "--force" ]] && FORCE=1
[[ -d "$DEADFALL_ROOT/.git" ]] || die "Repositorio no instalado: $DEADFALL_ROOT"
run_deadfall git -C "$DEADFALL_ROOT" fetch --prune origin "$DEADFALL_BRANCH"
OLD="$(run_deadfall git -C "$DEADFALL_ROOT" rev-parse HEAD)"; NEW="$(run_deadfall git -C "$DEADFALL_ROOT" rev-parse "origin/$DEADFALL_BRANCH")"
CHANGED=""; if [[ "$INITIAL" -eq 1 || "$FORCE" -eq 1 || "$OLD" == "$NEW" ]]; then [[ "$OLD" == "$NEW" && "$INITIAL" -eq 0 && "$FORCE" -eq 0 ]] && { log "Sin actualizaciones ($OLD)."; exit 0; }; CHANGED="ALL"; else CHANGED="$(run_deadfall git -C "$DEADFALL_ROOT" diff --name-only "$OLD..$NEW")"; fi
run_deadfall git -C "$DEADFALL_ROOT" reset --hard "$NEW"

APP=0; SERVER=0; WEB=0
if [[ "$CHANGED" == "ALL" ]]; then APP=1; SERVER=1; WEB=1; else
  grep -Eq '^(project\.godot|export_presets\.cfg|src/|assets/|android/)' <<<"$CHANGED" && { APP=1; SERVER=1; }
  grep -Eq '^(src/(server|network|core|horde|zombies|campaign)/|scripts/server/|deploy/(systemd|vps)/)' <<<"$CHANGED" && SERVER=1
  grep -Eq '^(web/download-site/|deploy/nginx/)' <<<"$CHANGED" && WEB=1
fi
log "Cambios detectados: app=$APP server=$SERVER web=$WEB"
cd "$DEADFALL_ROOT"
if [[ "$APP" -eq 1 || "$SERVER" -eq 1 ]]; then run_deadfall godot --headless --editor --path "$DEADFALL_ROOT" --quit; run_deadfall godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/smoke.gd; run_deadfall godot --headless --path "$DEADFALL_ROOT" --script scripts/ci/beta_hardening_smoke.gd; fi
if [[ "$APP" -eq 1 ]]; then "$DEADFALL_ROOT/scripts/build/build_android_vps.sh"; fi
if [[ "$WEB" -eq 1 || "$APP" -eq 1 ]]; then "$DEADFALL_ROOT/scripts/build/build_download_site.sh"; fi
if [[ "$SERVER" -eq 1 ]]; then systemctl restart nexora-deadfall; fi
if [[ "$WEB" -eq 1 || "$APP" -eq 1 ]]; then systemctl restart nexora-deadfall-download; fi
cp "$DEADFALL_ROOT/deploy/vps/nexora-deadfall" /usr/local/bin/nexora-deadfall; chmod 0755 /usr/local/bin/nexora-deadfall
json_state "last_deployed_sha=$NEW" "last_app_rebuild=$APP" "last_server_restart=$SERVER" "last_web_rebuild=$WEB"
log "Actualización completada: $NEW"

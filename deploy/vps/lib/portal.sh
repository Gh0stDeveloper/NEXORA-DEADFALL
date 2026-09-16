#!/usr/bin/env bash
# Shared by the VPS updater and the standalone portal regression.
# The caller supplies die() and DEADFALL_PUBLIC_DIR.

portal_expect_text(){
  local url="$1" expected="$2" body
  body="$(curl -fsS --max-time 5 "$url")" || die "El portal no responde correctamente: $url"
  grep -Fq -- "$expected" <<<"$body" || die "Falta '$expected' en el portal: $url"
}

validate_portal_routes(){
  local base_url="$1" current_version invalid_status public_sha
  portal_expect_text "$base_url/" "DEADFALL."
  portal_expect_text "$base_url/versiones" "Historial de versiones."
  current_version="$(jq -r '.current // empty' "$DEADFALL_PUBLIC_DIR/releases.json")"
  [[ -n "$current_version" ]] || die "El historial público no declara current."
  curl -fsS --max-time 5 "$base_url/releases.json" |
    jq -e --arg current "$current_version" '.schema_version == 1 and .current == $current and ([.releases[] | select(.version == $current)] | length) == 1' >/dev/null ||
    die "El endpoint público de historial no coincide con current."
  portal_expect_text "$base_url/versiones/$current_version" "Integridad del archivo"
  invalid_status="$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "$base_url/versiones/no-existe")" ||
    die "No se pudo comprobar la ruta de versión inexistente."
  [[ "$invalid_status" == "404" ]] || die "El portal no devuelve 404 para una versión inexistente."
  if [[ -f "$DEADFALL_PUBLIC_DIR/release.json" ]]; then
    public_sha="$(jq -r '.sha256 // empty' "$DEADFALL_PUBLIC_DIR/release.json")"
    if [[ -n "$public_sha" ]]; then
      portal_expect_text "$base_url/versiones/$current_version" "$public_sha"
    fi
  fi
}

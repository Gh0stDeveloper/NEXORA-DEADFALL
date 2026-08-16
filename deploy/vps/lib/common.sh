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
run_deadfall_home(){
  sudo -H -u "$DEADFALL_USER" -- bash -c 'cd "$HOME" && exec "$@"' bash "$@"
}
ensure_dirs(){
  install -d -m 0755 "$DEADFALL_HOME" "$DEADFALL_BUILD_DIR" "$DEADFALL_PUBLIC_DIR" "$DEADFALL_DOWNLOAD_DIR" "$DEADFALL_LOG_DIR"
  install -d -m 0750 "$DEADFALL_ETC" "$DEADFALL_ETC/signing"
  chown -R "$DEADFALL_USER:$DEADFALL_GROUP" "$DEADFALL_HOME" "$DEADFALL_LOG_DIR"
  chown -R www-data:www-data "$DEADFALL_PUBLIC_DIR"
}
configure_nginx_site(){
  local template="$1"
  local domain="${2:-_}"
  [[ -f "$template" ]] || die "Plantilla Nginx no encontrada: $template"
  [[ -f /etc/nginx/nginx.conf ]] || die "Nginx instalado pero falta /etc/nginx/nginx.conf"
  [[ "$domain" == "_" || "$domain" =~ ^[A-Za-z0-9.-]+$ ]] || die "Dominio Nginx inválido: $domain"

  install -d -m 0755 /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/conf.d
  local rendered
  rendered="$(mktemp)"
  sed -e "s/__DEADFALL_DOMAIN__/${domain:-_}/g" "$template" > "$rendered"

  local cert_dir="/etc/letsencrypt/live/$domain"
  if [[ "$domain" != "_" && -f "$cert_dir/fullchain.pem" && -f "$cert_dir/privkey.pem" ]]; then
    cat >> "$rendered" <<EOF

# Managed by NEXORA: DEADFALL. This block is regenerated from the persisted
# Let's Encrypt certificate so updater runs cannot erase the HTTPS vhost.
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain;

    ssl_certificate $cert_dir/fullchain.pem;
    ssl_certificate_key $cert_dir/privkey.pem;

    location = /downloads/NEXORA-DEADFALL-latest.apk {
        alias /var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk;
        default_type application/vnd.android.package-archive;
        add_header Cache-Control "no-store" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Content-Disposition "attachment; filename=NEXORA-DEADFALL-latest.apk" always;
    }

    location / {
        proxy_pass http://127.0.0.1:3100;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }
}
EOF
    log "Nginx: certificado existente detectado; vhost HTTPS administrado para $domain."
  fi

  if grep -Eq 'include[[:space:]]+/etc/nginx/sites-enabled/\*' /etc/nginx/nginx.conf; then
    install -m 0644 "$rendered" /etc/nginx/sites-available/nexora-deadfall
    ln -sf /etc/nginx/sites-available/nexora-deadfall /etc/nginx/sites-enabled/nexora-deadfall
    rm -f /etc/nginx/conf.d/nexora-deadfall.conf
    rm -f /etc/nginx/sites-enabled/default
    log "Nginx: usando sites-enabled."
  elif grep -Eq 'include[[:space:]]+/etc/nginx/conf\.d/\*\.conf' /etc/nginx/nginx.conf; then
    install -m 0644 "$rendered" /etc/nginx/conf.d/nexora-deadfall.conf
    rm -f /etc/nginx/sites-enabled/nexora-deadfall
    log "Nginx: usando conf.d."
  else
    rm -f "$rendered"
    die "nginx.conf no carga /etc/nginx/sites-enabled/* ni /etc/nginx/conf.d/*.conf; no se modificará automáticamente una configuración Nginx no estándar."
  fi
  rm -f "$rendered"
  nginx -t
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

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/deploy/vps/lib/common.sh"
require_root

DOMAIN=""; EMAIL=""; REPO="Gh0stDeveloper/NEXORA-DEADFALL"; BRANCH="main"; PUBLIC_HOST=""; ROOM_CODE=""; SKIP_HTTPS=0; TOKEN_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2;; --email) EMAIL="$2"; shift 2;; --repo) REPO="$2"; shift 2;; --branch) BRANCH="$2"; shift 2;;
    --public-host) PUBLIC_HOST="$2"; shift 2;; --room) ROOM_CODE="$2"; shift 2;; --skip-https) SKIP_HTTPS=1; shift;;
    --github-token-file) TOKEN_FILE="$2"; shift 2;; *) die "Argumento desconocido: $1";; esac
done

[[ -r /etc/os-release ]] || die "No se pudo detectar Ubuntu."; source /etc/os-release
[[ "$ID" == "ubuntu" ]] || die "Phase 10 soporta Ubuntu 24.04 LTS."; [[ "${VERSION_ID%%.*}" -ge 24 ]] || die "Se requiere Ubuntu 24.04 o posterior."

if id "$DEADFALL_USER" >/dev/null 2>&1; then log "Usuario $DEADFALL_USER existente."; else useradd --system --create-home --home-dir "$DEADFALL_HOME" --shell /bin/bash "$DEADFALL_USER"; fi
ensure_dirs

log "Instalando dependencias base..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git jq unzip zip xz-utils rsync sudo nginx certbot python3-certbot-nginx openjdk-17-jdk-headless build-essential libfontconfig1 libgl1 libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 ufw gh

ARCH_RAW="$(uname -m)"; case "$ARCH_RAW" in x86_64) GODOT_ARCH="x86_64"; NODE_ARCH="x64";; aarch64|arm64) GODOT_ARCH="arm64"; NODE_ARCH="arm64";; *) die "Arquitectura no soportada: $ARCH_RAW";; esac
GODOT_VERSION="4.6.3"
if ! command -v godot >/dev/null 2>&1 || [[ "$(godot --version 2>/dev/null || true)" != 4.6.3* ]]; then
  log "Instalando Godot $GODOT_VERSION para $GODOT_ARCH..."
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  curl -fL -o "$TMP/godot.zip" "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.${GODOT_ARCH}.zip"
  unzip -q "$TMP/godot.zip" -d "$TMP/godot"
  install -m 0755 "$TMP/godot/Godot_v${GODOT_VERSION}-stable_linux.${GODOT_ARCH}" /usr/local/bin/godot
  curl -fL -o "$TMP/templates.tpz" "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  install -d "$DEADFALL_HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
  unzip -q "$TMP/templates.tpz" -d "$TMP/templates"
  cp -a "$TMP/templates/templates/." "$DEADFALL_HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable/"
  chown -R "$DEADFALL_USER:$DEADFALL_GROUP" "$DEADFALL_HOME/.local"
fi

if ! command -v node >/dev/null 2>&1 || [[ "$(node -p 'process.versions.node.split(`.`)[0]' 2>/dev/null || echo 0)" -lt 24 ]]; then
  log "Instalando Node.js 24 LTS desde nodejs.org..."
  TMP_NODE="$(mktemp -d)"; NODE_FILE="$(curl -fsSL https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt | awk -v a="$NODE_ARCH" '$2 ~ ("linux-" a ".tar.xz$"){print $2;exit}')"
  [[ -n "$NODE_FILE" ]] || die "No se encontró Node.js 24 para $NODE_ARCH"
  curl -fL -o "$TMP_NODE/$NODE_FILE" "https://nodejs.org/dist/latest-v24.x/$NODE_FILE"
  tar -xJf "$TMP_NODE/$NODE_FILE" -C /usr/local --strip-components=1
  rm -rf "$TMP_NODE"
fi

ANDROID_HOME="/opt/android-sdk"; CMDTOOLS_VERSION="15859902"; CMDTOOLS_SHA="4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"
if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  log "Instalando Android SDK command-line tools..."
  install -d "$ANDROID_HOME/cmdline-tools"
  TMP_ANDROID="$(mktemp -d)"; curl -fL -o "$TMP_ANDROID/tools.zip" "https://dl.google.com/android/repository/commandlinetools-linux-${CMDTOOLS_VERSION}_latest.zip"
  echo "$CMDTOOLS_SHA  $TMP_ANDROID/tools.zip" | sha256sum -c -
  unzip -q "$TMP_ANDROID/tools.zip" -d "$TMP_ANDROID/unpack"
  mv "$TMP_ANDROID/unpack/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$TMP_ANDROID"
fi
export ANDROID_HOME JAVA_HOME="/usr/lib/jvm/java-17-openjdk-${ARCH_RAW/aarch64/arm64}"
[[ -d "$JAVA_HOME" ]] || JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" --licenses >/dev/null || true
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" "platform-tools" "build-tools;35.0.1" "platforms;android-35" "platforms;android-36" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709"
chown -R "$DEADFALL_USER:$DEADFALL_GROUP" "$ANDROID_HOME"

install -d "$DEADFALL_HOME/.config/godot"
cat > "$DEADFALL_HOME/.config/godot/editor_settings-4.tres" <<EOF
[gd_resource type="EditorSettings" format=3]
[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
EOF
chown -R "$DEADFALL_USER:$DEADFALL_GROUP" "$DEADFALL_HOME/.config"

if [[ -n "$TOKEN_FILE" ]]; then [[ -r "$TOKEN_FILE" ]] || die "No se puede leer $TOKEN_FILE"; run_deadfall gh auth login --hostname github.com --git-protocol https --with-token < "$TOKEN_FILE"; fi
if ! run_deadfall gh auth status --hostname github.com >/dev/null 2>&1; then
  [[ -t 0 ]] || die "GitHub no está autenticado. Ejecuta: sudo -Hu $DEADFALL_USER gh auth login --hostname github.com --git-protocol https"
  log "Autenticando GitHub para clonar el repositorio privado..."; sudo -Hu "$DEADFALL_USER" gh auth login --hostname github.com --git-protocol https --skip-ssh-key
fi
run_deadfall gh auth setup-git --hostname github.com

if [[ ! -d "$DEADFALL_ROOT/.git" ]]; then
  log "Clonando $REPO ($BRANCH)..."; rm -rf "$DEADFALL_ROOT"; install -d -o "$DEADFALL_USER" -g "$DEADFALL_GROUP" "$DEADFALL_ROOT"
  run_deadfall git clone --branch "$BRANCH" "https://github.com/${REPO}.git" "$DEADFALL_ROOT"
else
  log "Instalación existente detectada; se conservarán keystore, estado y artefactos."
fi

if [[ -z "$DOMAIN" && -f "$DEADFALL_ENV" ]]; then source "$DEADFALL_ENV"; DOMAIN="${DEADFALL_DOMAIN:-}"; EMAIL="${DEADFALL_EMAIL:-}"; fi
[[ -n "$PUBLIC_HOST" ]] || PUBLIC_HOST="${DOMAIN:-127.0.0.1}"
[[ -n "$ROOM_CODE" ]] || ROOM_CODE="$(tr -dc 'A-HJ-NP-Z2-9' </dev/urandom | head -c 6 || true)"; [[ ${#ROOM_CODE} -eq 6 ]] || ROOM_CODE="DEAD42"

if [[ ! -f "$DEADFALL_KEYSTORE" ]]; then
  log "Generando keystore Release persistente (solo primera instalación)..."
  STOREPASS="$(openssl rand -hex 24)"; ALIAS="deadfall-upload"
  keytool -genkeypair -noprompt -keystore "$DEADFALL_KEYSTORE" -storepass "$STOREPASS" -keypass "$STOREPASS" -alias "$ALIAS" -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=NEXORA DEADFALL,O=Ghost Developer,C=MX"
  cat > "$DEADFALL_KEYSTORE_META" <<EOF
DEADFALL_KEYSTORE_ALIAS='$ALIAS'
DEADFALL_KEYSTORE_PASSWORD='$STOREPASS'
EOF
  chmod 0600 "$DEADFALL_KEYSTORE" "$DEADFALL_KEYSTORE_META"; chown root:root "$DEADFALL_KEYSTORE" "$DEADFALL_KEYSTORE_META"
else log "Keystore existente: NO se regenera."; fi

cat > "$DEADFALL_ENV" <<EOF
DEADFALL_REPO='$REPO'
DEADFALL_BRANCH='$BRANCH'
DEADFALL_DOMAIN='$DOMAIN'
DEADFALL_EMAIL='$EMAIL'
DEADFALL_PUBLIC_HOST='$PUBLIC_HOST'
DEADFALL_ROOM_CODE='$ROOM_CODE'
DEADFALL_PORT='24560'
DEADFALL_DIRECTORY_PORT='24561'
ANDROID_HOME='$ANDROID_HOME'
JAVA_HOME='$JAVA_HOME'
DEADFALL_ROOT='$DEADFALL_ROOT'
DEADFALL_HOME='$DEADFALL_HOME'
DEADFALL_DOWNLOAD_DIR='$DEADFALL_DOWNLOAD_DIR'
EOF
chmod 0640 "$DEADFALL_ENV"; chown root:"$DEADFALL_GROUP" "$DEADFALL_ENV"

cp "$DEADFALL_ROOT/deploy/vps/nexora-deadfall" /usr/local/bin/nexora-deadfall; chmod 0755 /usr/local/bin/nexora-deadfall
cp "$DEADFALL_ROOT/deploy/systemd/nexora-deadfall.service" /etc/systemd/system/nexora-deadfall.service
cp "$DEADFALL_ROOT/deploy/systemd/nexora-deadfall-download.service" /etc/systemd/system/nexora-deadfall-download.service
sed -e "s/__DEADFALL_DOMAIN__/${DOMAIN:-_}/g" "$DEADFALL_ROOT/deploy/nginx/nexora-deadfall.conf.template" > /etc/nginx/sites-available/nexora-deadfall
ln -sf /etc/nginx/sites-available/nexora-deadfall /etc/nginx/sites-enabled/nexora-deadfall; rm -f /etc/nginx/sites-enabled/default
nginx -t; systemctl daemon-reload; systemctl enable nginx nexora-deadfall nexora-deadfall-download
ufw allow OpenSSH >/dev/null || true; ufw allow 80/tcp >/dev/null || true; ufw allow 443/tcp >/dev/null || true; ufw allow 24560/udp >/dev/null || true; ufw allow 24561/tcp >/dev/null || true

json_state "installed=true" "repo=$REPO" "branch=$BRANCH" "domain=$DOMAIN" "keystore=$DEADFALL_KEYSTORE"
"$DEADFALL_ROOT/deploy/vps/update.sh" --initial

if [[ "$SKIP_HTTPS" -eq 0 && -n "$DOMAIN" && -n "$EMAIL" ]]; then
  if getent ahostsv4 "$DOMAIN" >/dev/null 2>&1; then certbot --nginx --non-interactive --agree-tos --redirect -m "$EMAIL" -d "$DOMAIN" || warn "HTTPS no pudo activarse todavía; revisa DNS y ejecuta: nexora-deadfall https"; fi
fi
log "Instalación terminada. Estado: nexora-deadfall status"

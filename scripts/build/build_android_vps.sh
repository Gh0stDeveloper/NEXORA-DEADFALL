#!/usr/bin/env bash
set -euo pipefail
source /opt/nexora-deadfall/deploy/vps/lib/common.sh
require_root
load_env
source "$DEADFALL_KEYSTORE_META"

VERSION="$(grep -oP 'const APP_VERSION := "\K[^"]+' "$DEADFALL_ROOT/src/release/BuildInfo.gd")"
OUT="$DEADFALL_BUILD_DIR/NEXORA-DEADFALL-${VERSION}.apk"
TMP="$DEADFALL_BUILD_DIR/.NEXORA-DEADFALL-${VERSION}.tmp.apk"
BUILD_KEYSTORE="$DEADFALL_HOME/.deadfall-build.keystore"
ANDROID_BUILD_DIR="$DEADFALL_ROOT/android/build"
ANDROID_PATCHER="$DEADFALL_ROOT/scripts/build/patch_android_template.py"
ANDROID_GRADLE_INIT="$DEADFALL_ROOT/scripts/build/deadfall_android_init.gradle"
cleanup(){ rm -f "$BUILD_KEYSTORE" "$TMP"; }
trap cleanup EXIT

install -d -o "$DEADFALL_USER" -g "$DEADFALL_GROUP" "$DEADFALL_BUILD_DIR"
install -m 0600 -o "$DEADFALL_USER" -g "$DEADFALL_GROUP" "$DEADFALL_KEYSTORE" "$BUILD_KEYSTORE"
chown -R "$DEADFALL_USER:$DEADFALL_GROUP" "$DEADFALL_ROOT"

SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -d "$ANDROID_HOME/build-tools/36.0.0" ]]; then
  test -x "$SDKMANAGER"
  log "Instalando Android SDK Build-Tools 36.0.0 para targetSdk 36..."
  "$SDKMANAGER" --sdk_root="$ANDROID_HOME" "build-tools;36.0.0"
  chown -R "$DEADFALL_USER:$DEADFALL_GROUP" "$ANDROID_HOME/build-tools/36.0.0"
fi

if [[ ! -f "$ANDROID_BUILD_DIR/build.gradle" ]]; then
  rm -rf "$ANDROID_BUILD_DIR"
  log "Android Gradle build template ausente; instalándolo antes de exportar Release..."
  run_deadfall_home env \
    ANDROID_HOME="$ANDROID_HOME" \
    JAVA_HOME="$JAVA_HOME" \
    godot --headless --path "$DEADFALL_ROOT" --install-android-build-template --quit
  test -f "$ANDROID_BUILD_DIR/build.gradle"
fi

test -f "$ANDROID_PATCHER"
test -f "$ANDROID_GRADLE_INIT"
log "Aplicando compatibilidad reproducible al template Android generado..."
python3 "$ANDROID_PATCHER" "$ANDROID_BUILD_DIR"
chown -R "$DEADFALL_USER:$DEADFALL_GROUP" "$ANDROID_BUILD_DIR"

# Godot may refresh src/release/AndroidManifest.xml immediately before invoking
# Gradle. GRADLE_OPTS installs our init hook into that child Gradle invocation,
# so the four redundant tools:replace markers are removed immediately before
# processStandardReleaseMainManifest rather than relying on a stale generated
# file from a previous build.
run_deadfall_home env \
  ANDROID_HOME="$ANDROID_HOME" \
  JAVA_HOME="$JAVA_HOME" \
  DEADFALL_ROOT="$DEADFALL_ROOT" \
  GRADLE_OPTS="${GRADLE_OPTS:-} -I $ANDROID_GRADLE_INIT" \
  GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$BUILD_KEYSTORE" \
  GODOT_ANDROID_KEYSTORE_RELEASE_USER="$DEADFALL_KEYSTORE_ALIAS" \
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$DEADFALL_KEYSTORE_PASSWORD" \
  godot --verbose --headless --path "$DEADFALL_ROOT" \
  --export-release "Android Closed Beta APK" "$TMP"

test -s "$TMP"
APKSIGNER="$(find "$ANDROID_HOME/build-tools" -type f -name apksigner | sort -V | tail -n1)"
test -x "$APKSIGNER"
"$APKSIGNER" verify --verbose "$TMP"
mv "$TMP" "$OUT"
SHA="$(sha256sum "$OUT" | awk '{print $1}')"
BYTES="$(stat -c %s "$OUT")"
PUBLISHED="$DEADFALL_DOWNLOAD_DIR/NEXORA-DEADFALL-latest.apk"
install -m 0644 "$OUT" "$PUBLISHED.tmp"
mv "$PUBLISHED.tmp" "$PUBLISHED"
python3 - "$DEADFALL_PUBLIC_DIR/release.json" "$VERSION" "$SHA" "$BYTES" "$(git -C "$DEADFALL_ROOT" rev-parse HEAD)" <<'PY'
import json,sys,time,pathlib
p=pathlib.Path(sys.argv[1])
p.write_text(json.dumps({
    'version':sys.argv[2],
    'sha256':sys.argv[3],
    'bytes':int(sys.argv[4]),
    'git_sha':sys.argv[5],
    'published_unix':int(time.time()),
    'download':'/downloads/NEXORA-DEADFALL-latest.apk'
},indent=2)+'\n')
PY
chown www-data:www-data "$PUBLISHED" "$DEADFALL_PUBLIC_DIR/release.json"
chmod 0644 "$PUBLISHED" "$DEADFALL_PUBLIC_DIR/release.json"
log "APK Release verificada y publicada: $PUBLISHED ($VERSION)"

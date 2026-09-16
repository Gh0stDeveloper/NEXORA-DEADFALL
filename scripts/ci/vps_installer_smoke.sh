#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

for file in \
  deploy/vps/install.sh \
  deploy/vps/update.sh \
  deploy/vps/nexora-deadfall \
  deploy/vps/lib/common.sh \
  scripts/build/build_android_vps.sh \
  scripts/build/build_download_site.sh \
  scripts/server/run_server.sh; do
  bash -n "$file"
done

for file in \
  deploy/systemd/nexora-deadfall.service \
  deploy/systemd/nexora-deadfall-download.service \
  deploy/nginx/nexora-deadfall.conf.template \
  docs/VPS_INSTALLER.md \
  web/download-site/package.json \
  web/download-site/next.config.ts \
  web/download-site/src/app/page.tsx \
  web/download-site/src/app/versions/page.tsx \
  web/download-site/src/app/versions/[version]/page.tsx \
  web/download-site/src/data/releases.json \
  web/download-site/src/lib/releases.ts \
  web/download-site/scripts/publish_release_history.py \
  scripts/ci/download_portal_smoke.sh \
  assets/branding/deadfall_icon.svg \
  scripts/build/patch_android_template.py \
  scripts/build/deadfall_android_init.gradle \
  scripts/ci/android_template_patch_smoke.sh \
  scripts/ci/download_portal_smoke.sh; do
  test -s "$file"
done

grep -Fq 'config/icon="res://assets/branding/deadfall_icon.svg"' project.godot
grep -Fq 'deadfall-release.keystore' deploy/vps/lib/common.sh
grep -Fq 'Keystore existente: NO se regenera' deploy/vps/install.sh
grep -Fq 'gh auth setup-git' deploy/vps/install.sh
grep -Fq 'gh auth login --hostname github.com --git-protocol https' deploy/vps/install.sh
grep -Fq 'install -m 0755 "$ROOT/deploy/vps/nexora-deadfall" /usr/local/bin/nexora-deadfall' deploy/vps/install.sh
grep -Fq 'run_deadfall_home' deploy/vps/lib/common.sh
grep -Fq 'run_deadfall_home gh auth setup-git' deploy/vps/install.sh
grep -Fq 'run_deadfall_home git clone' deploy/vps/install.sh
grep -Fq 'checkout -B "$BRANCH" "origin/$BRANCH"' deploy/vps/install.sh
grep -Fq 'configure_nginx_site' deploy/vps/lib/common.sh
grep -Fq 'configure_nginx_site "$DEADFALL_ROOT/deploy/nginx/nexora-deadfall.conf.template"' deploy/vps/install.sh
grep -Fq 'configure_nginx_site "$DEADFALL_ROOT/deploy/nginx/nexora-deadfall.conf.template"' deploy/vps/update.sh
grep -Fq '/etc/nginx/sites-enabled/' deploy/vps/lib/common.sh
grep -Fq '/etc/nginx/conf.d/' deploy/vps/lib/common.sh
grep -Fq 'listen 443 ssl http2;' deploy/vps/lib/common.sh
grep -Fq 'ssl_certificate $cert_dir/fullchain.pem;' deploy/vps/lib/common.sh
grep -Fq 'vhost HTTPS administrado' deploy/vps/lib/common.sh
grep -Fq 'last_deployed_sha' deploy/vps/update.sh
grep -Fq 'last_deploy_status=failed' deploy/vps/update.sh
grep -Fq 'last_deploy_status=success' deploy/vps/update.sh
grep -Fq "volverá a ejecutar los gates/builds" deploy/vps/update.sh
grep -Fq 'Portal Next.js validado en localhost y HTTPS' deploy/vps/update.sh
grep -Fq 'validate_portal_routes' deploy/vps/update.sh
grep -Fq 'download_portal_smoke.sh' deploy/vps/update.sh
grep -Fq 'releases.json' scripts/build/build_download_site.sh
grep -Fq 'publish_release_history.py' scripts/build/build_android_vps.sh
grep -Fq '/releases.json' deploy/vps/lib/common.sh
grep -Fq '/releases.json' deploy/nginx/nexora-deadfall.conf.template
grep -Fq 'El puerto HTTP/80 local no pertenece a DEADFALL' deploy/vps/update.sh
grep -Fq 'http://127.0.0.1:3100/' deploy/vps/update.sh
grep -Fq -- '--resolve "$DEADFALL_DOMAIN:443:127.0.0.1"' deploy/vps/update.sh
grep -Fq 'configure_nginx_site "$1/deploy/nginx/nexora-deadfall.conf.template" "$2"' deploy/vps/nexora-deadfall
if grep -Fq -- '--skip-ssh-key' deploy/vps/install.sh || grep -Fq -- '--skip-ssh-key' deploy/vps/nexora-deadfall; then
  echo 'Unsupported gh --skip-ssh-key flag must not be used by VPS scripts' >&2
  exit 1
fi
if grep -Fq '"cmdline-tools;latest"' deploy/vps/install.sh; then
  echo 'Installer must not reinstall cmdline-tools;latest over the manually installed tools' >&2
  exit 1
fi
if grep -Fq '> /etc/nginx/sites-available/nexora-deadfall' deploy/vps/install.sh || grep -Fq '> /etc/nginx/sites-available/nexora-deadfall' deploy/vps/update.sh; then
  echo 'Installer/updater must use configure_nginx_site instead of assuming sites-available exists' >&2
  exit 1
fi
if grep -Fq 'JSON.parse_string' src/campaign/CampaignSaveStore.gd; then
  echo 'CampaignSaveStore must parse corrupt-save candidates without emitting JSON parser noise' >&2
  exit 1
fi
grep -Fq 'cmdline-tools/latest-2' deploy/vps/install.sh
grep -Fq 'platforms;android-36' deploy/vps/install.sh
grep -Fq 'build-tools;36.0.0' deploy/vps/install.sh
grep -Fq 'Node.js 24 LTS' deploy/vps/install.sh
grep -Fq 'reboot-required' deploy/vps/install.sh
grep -Fq 'NEXORA-DEADFALL-latest.apk' scripts/build/build_android_vps.sh
grep -Fq 'apksigner' scripts/build/build_android_vps.sh
grep -Fq 'ANDROID_BUILD_DIR="$DEADFALL_ROOT/android/build"' scripts/build/build_android_vps.sh
grep -Fq 'if [[ ! -f "$ANDROID_BUILD_DIR/build.gradle" ]]' scripts/build/build_android_vps.sh
grep -Fq -- '--install-android-build-template --quit' scripts/build/build_android_vps.sh
grep -Fq 'patch_android_template.py' scripts/build/build_android_vps.sh
grep -Fq 'deadfall_android_init.gradle' scripts/build/build_android_vps.sh
grep -Fq 'GRADLE_INIT_DIR="$DEADFALL_HOME/.gradle/init.d"' scripts/build/build_android_vps.sh
grep -Fq 'run_deadfall_home env' scripts/build/build_android_vps.sh
grep -Fq 'Instalando Android SDK Build-Tools 36.1.0 requerido por Godot 4.6.3' scripts/build/build_android_vps.sh
grep -Fq 'android.suppressUnsupportedCompileSdk' scripts/build/patch_android_template.py
grep -Fq 'processStandardReleaseMainManifest' scripts/build/deadfall_android_init.gradle
grep -Fq 'func is_dedicated_server() -> bool:' src/autoload/Game.gd
grep -Fq 'APP=0; SERVER=0; WEB=0; DEPLOY=0' deploy/vps/update.sh
grep -Fq 'scripts/build/' deploy/vps/update.sh
grep -Fq 'APP=1; SERVER=1; WEB=1; DEPLOY=1' deploy/vps/update.sh
grep -Fq 'output:' web/download-site/next.config.ts || grep -Fq "output: 'standalone'" web/download-site/next.config.ts
grep -Fq 'proxy_pass http://127.0.0.1:3100' deploy/nginx/nexora-deadfall.conf.template
grep -Fq '24560/udp' docs/VPS_INSTALLER.md
grep -Fq '24561/tcp' docs/VPS_INSTALLER.md

python3 -m py_compile web/download-site/scripts/publish_release_history.py
python3 - <<'PY'
import json
from pathlib import Path
p=json.load(open('web/download-site/package.json'))
assert p['dependencies']['next']=='16.2.11'
assert p['dependencies']['react']=='19.2.8'
assert p['dependencies']['react-dom']=='19.2.8'
update=Path('deploy/vps/update.sh').read_text()
assert update.index('build_download_site.sh') < update.index('build_android_vps.sh'), 'portal must deploy before Android build'
assert update.index('https://$DEADFALL_DOMAIN/') < update.index('El puerto HTTP/80 local no pertenece a DEADFALL'), 'HTTPS must be authoritative when a certificate exists'
release=Path('.github/workflows/closed-beta-release.yml').read_text()
assert 'Resolve release identity from BuildInfo' in release
assert 'DEADFALL_VERSION: "0.9.0-beta.1"' not in release
assert 'build-tools;36.1.0' in release
assert 'download_portal_smoke.sh' in update
assert 'scripts/build/build_download_site\\.sh' in update
history = json.load(open('web/download-site/src/data/releases.json', encoding='utf-8'))
assert history['schema_version'] == 1
assert history['current'] == '0.9.0-beta.5'
assert sum(item['version'] == history['current'] for item in history['releases']) == 1
assert any(item['status'] == 'superseded' for item in history['releases'])
PY

echo 'NEXORA: DEADFALL Phase 10 VPS installer smoke passed'

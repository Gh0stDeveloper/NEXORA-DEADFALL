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
  web/download-site/src/app/page.tsx; do
  test -s "$file"
done

grep -Fq 'deadfall-release.keystore' deploy/vps/install.sh
grep -Fq 'Keystore existente: NO se regenera' deploy/vps/install.sh
grep -Fq 'gh auth setup-git' deploy/vps/install.sh
grep -Fq 'gh auth login --hostname github.com --git-protocol https' deploy/vps/install.sh
grep -Fq 'install -m 0755 "$ROOT/deploy/vps/nexora-deadfall" /usr/local/bin/nexora-deadfall' deploy/vps/install.sh
grep -Fq 'run_deadfall_home' deploy/vps/lib/common.sh
grep -Fq 'run_deadfall_home gh auth setup-git' deploy/vps/install.sh
grep -Fq 'run_deadfall_home git clone' deploy/vps/install.sh
if grep -Fq -- '--skip-ssh-key' deploy/vps/install.sh || grep -Fq -- '--skip-ssh-key' deploy/vps/nexora-deadfall; then
  echo 'Unsupported gh --skip-ssh-key flag must not be used by VPS scripts' >&2
  exit 1
fi
if grep -Fq '"cmdline-tools;latest"' deploy/vps/install.sh; then
  echo 'Installer must not reinstall cmdline-tools;latest over the manually installed tools' >&2
  exit 1
fi
grep -Fq 'cmdline-tools/latest-2' deploy/vps/install.sh
grep -Fq 'platforms;android-36' deploy/vps/install.sh
grep -Fq 'Node.js 24 LTS' deploy/vps/install.sh
grep -Fq 'reboot-required' deploy/vps/install.sh
grep -Fq 'NEXORA-DEADFALL-latest.apk' scripts/build/build_android_vps.sh
grep -Fq 'apksigner' scripts/build/build_android_vps.sh
grep -Fq 'APP=0; SERVER=0; WEB=0; DEPLOY=0' deploy/vps/update.sh
grep -Fq 'output:' web/download-site/next.config.ts || grep -Fq "output: 'standalone'" web/download-site/next.config.ts
grep -Fq 'proxy_pass http://127.0.0.1:3100' deploy/nginx/nexora-deadfall.conf.template
grep -Fq '24560/udp' docs/VPS_INSTALLER.md
grep -Fq '24561/tcp' docs/VPS_INSTALLER.md

python3 - <<'PY'
import json
p=json.load(open('web/download-site/package.json'))
assert p['dependencies']['next']=='16.2.11'
assert p['dependencies']['react']=='19.2.8'
assert p['dependencies']['react-dom']=='19.2.8'
PY

echo 'NEXORA: DEADFALL Phase 10 VPS installer smoke passed'

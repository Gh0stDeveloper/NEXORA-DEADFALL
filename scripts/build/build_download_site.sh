#!/usr/bin/env bash
set -euo pipefail
source /opt/nexora-deadfall/deploy/vps/lib/common.sh
require_root
load_env
SITE="$DEADFALL_ROOT/web/download-site"
DEST="$DEADFALL_HOME/download-site"
HISTORY_PUBLISHER="$SITE/scripts/publish_release_history.py"

[[ -f "$HISTORY_PUBLISHER" ]] || die "Falta el publicador de historial durable: $HISTORY_PUBLISHER"
python3 "$HISTORY_PUBLISHER"   --source "$SITE/src/data/releases.json"   --current "$DEADFALL_PUBLIC_DIR/release.json"   --output "$DEADFALL_PUBLIC_DIR/releases.json"
chown www-data:www-data "$DEADFALL_PUBLIC_DIR/releases.json"
chmod 0644 "$DEADFALL_PUBLIC_DIR/releases.json"

cd "$SITE"
run_deadfall npm install --package-lock=false --no-audit --no-fund
run_deadfall npm run build
rm -rf "$DEST.new"
install -d -o "$DEADFALL_USER" -g "$DEADFALL_GROUP" "$DEST.new"
cp -a .next/standalone/. "$DEST.new/"
install -d "$DEST.new/.next"
cp -a .next/static "$DEST.new/.next/static"
[[ -d public ]] && cp -a public "$DEST.new/public"
chown -R "$DEADFALL_USER:$DEADFALL_GROUP" "$DEST.new"
rm -rf "$DEST.old"
[[ -d "$DEST" ]] && mv "$DEST" "$DEST.old"
mv "$DEST.new" "$DEST"
rm -rf "$DEST.old"
log "Portal Next.js e historial durable actualizados en $DEST"

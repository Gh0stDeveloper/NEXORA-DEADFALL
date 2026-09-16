#!/usr/bin/env bash
set -euo pipefail

PACKAGE="${1:-com.nexora.deadfall}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${2:-deadfall-beta-report-${STAMP}}"
mkdir -p "$OUT"

adb wait-for-device
adb shell getprop > "$OUT/device-getprop.txt" || true
adb shell dumpsys package "$PACKAGE" > "$OUT/package.txt" || true
adb shell dumpsys meminfo "$PACKAGE" > "$OUT/meminfo.txt" || true
adb shell dumpsys thermalservice > "$OUT/thermal.txt" || true
adb logcat -d -v threadtime > "$OUT/logcat.txt" || true
adb shell pidof "$PACKAGE" > "$OUT/pid.txt" || true

cat > "$OUT/README.txt" <<EOF
NEXORA: DEADFALL Closed Beta diagnostic bundle
Generated UTC: ${STAMP}
Package: ${PACKAGE}

Review logcat for DEADFALL_* runtime markers and crash/ANR entries before sharing.
The game-side BetaRuntime intentionally avoids storing resume tokens/passwords/host addresses.
EOF

tar -czf "${OUT}.tar.gz" "$OUT"
echo "Created ${OUT}.tar.gz"

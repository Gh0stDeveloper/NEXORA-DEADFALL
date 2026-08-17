#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src/release"
cat > "$TMP/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2048m
android.overridePathCheck=true
EOF
cat > "$TMP/src/release/AndroidManifest.xml" <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">
    <uses-feature android:name="android.hardware.vulkan.level" android:required="false" tools:replace="android:required" />
    <uses-feature android:name="android.hardware.vulkan.version" android:required="false" tools:replace="android:required" />
    <uses-feature android:name="android.hardware.camera" android:required="false" tools:replace="android:required" />
    <application>
        <meta-data android:name="org.godotengine.rendering.method" android:value="mobile" tools:replace="android:value" />
        <meta-data android:name="org.godotengine.editor.version" android:value="4.6.3" tools:replace="android:value" />
        <meta-data android:name="unrelated.meta" android:value="keep" tools:replace="android:value" />
    </application>
</manifest>
EOF

python3 -m py_compile "$ROOT/scripts/build/patch_android_template.py"
python3 "$ROOT/scripts/build/patch_android_template.py" "$TMP" --require-manifest
python3 "$ROOT/scripts/build/patch_android_template.py" "$TMP" --require-manifest

grep -Fxq 'android.suppressUnsupportedCompileSdk=36' "$TMP/gradle.properties"
[[ "$(grep -c '^android.suppressUnsupportedCompileSdk=' "$TMP/gradle.properties")" -eq 1 ]]

python3 - "$TMP/src/release/AndroidManifest.xml" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text()
targets = {
    'android.hardware.vulkan.level',
    'android.hardware.vulkan.version',
    'org.godotengine.rendering.method',
    'org.godotengine.editor.version',
}
for tag in re.findall(r'<(?:uses-feature|meta-data)\b[^>]*?/?>', text):
    m = re.search(r'android:name="([^"]+)"', tag)
    if not m:
        continue
    name = m.group(1)
    if name in targets and 'tools:replace=' in tag:
        raise SystemExit(f'redundant tools:replace retained for {name}')
for name in ['android.hardware.camera', 'unrelated.meta']:
    matching = [tag for tag in re.findall(r'<(?:uses-feature|meta-data)\b[^>]*?/?>', text) if f'android:name="{name}"' in tag]
    if len(matching) != 1 or 'tools:replace=' not in matching[0]:
        raise SystemExit(f'unrelated manifest merger directive was modified for {name}')
PY

grep -Fq 'processStandardReleaseMainManifest' "$ROOT/scripts/build/deadfall_android_init.gradle"
grep -Fq 'deadfallSanitizeReleaseManifest' "$ROOT/scripts/build/deadfall_android_init.gradle"
grep -Fq '.gradle/init.d' "$ROOT/scripts/build/build_android_vps.sh"
grep -Fq 'ACTIVE_GRADLE_INIT' "$ROOT/scripts/build/build_android_vps.sh"
grep -Fq 'patch_android_template.py' "$ROOT/scripts/build/build_android_vps.sh"

echo 'NEXORA: DEADFALL Android template patch smoke passed'

#!/usr/bin/env bash
set -euo pipefail

APK="${1:-build/android/NEXORA-DEADFALL-emulator.apk}"
PACKAGE="com.nexora.deadfall"
LOG="/tmp/deadfall-android-logcat.txt"

if [[ ! -s "$APK" ]]; then
  echo "APK not found or empty: $APK" >&2
  exit 1
fi

adb wait-for-device
adb logcat -c
adb install -r "$APK"
adb shell am force-stop "$PACKAGE" || true
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/tmp/deadfall-monkey.txt 2>&1
sleep 8

PID="$(adb shell pidof "$PACKAGE" | tr -d '\r')"
if [[ -z "$PID" ]]; then
  echo "DEADFALL process is not alive after launch" >&2
  adb logcat -d || true
  exit 1
fi

echo "DEADFALL Android process: $PID"

# Pixel 7 emulator profile in landscape (2400x1080). These events exercise
# the actual Android touch path into the Godot HUD rather than calling scripts directly.
adb shell input tap 1886 966   # RUN
adb shell input tap 2268 966   # JUMP
adb shell input tap 2088 966   # CROUCH
adb shell input tap 2088 891   # PRONE
adb shell input tap 2268 891   # CAM
adb shell input swipe 228 898 360 898 450   # joystick
adb shell input swipe 1250 450 1600 450 450 # look area
sleep 3

adb logcat -d > "$LOG"

echo "--- DEADFALL runtime markers ---"
grep -E "NEXORA: DEADFALL client bootstrap ready|DEADFALL_ANDROID_READY|DEADFALL_GORE_STATS|DEADFALL_HORDE_STATS|DEADFALL_TOUCH_" "$LOG" || true

grep -Fq "NEXORA: DEADFALL client bootstrap ready" "$LOG"
grep -Fq "DEADFALL_ANDROID_READY" "$LOG"
grep -Fq '"landscape":true' "$LOG"
grep -Fq '"safe_area_valid":true' "$LOG"
grep -Fq '"gore_budget"' "$LOG"
grep -Fq '"horde"' "$LOG"
grep -Fq "DEADFALL_GORE_STATS" "$LOG"
grep -Fq "DEADFALL_HORDE_STATS" "$LOG"
grep -Fq '"population_budget"' "$LOG"
grep -Fq "DEADFALL_TOUCH_ACTION sprint" "$LOG"
grep -Fq "DEADFALL_TOUCH_ACTION jump" "$LOG"
grep -Fq "DEADFALL_TOUCH_ACTION crouch" "$LOG"
grep -Fq "DEADFALL_TOUCH_ACTION prone" "$LOG"
grep -Fq "DEADFALL_TOUCH_ACTION camera_cycle" "$LOG"
grep -Fq "DEADFALL_TOUCH_JOYSTICK active" "$LOG"
grep -Fq "DEADFALL_TOUCH_LOOK active" "$LOG"

if grep -E "SCRIPT ERROR|Parse Error|Invalid call|FATAL EXCEPTION|ANR in ${PACKAGE}" "$LOG"; then
  echo "Runtime errors detected in Android logcat" >&2
  exit 1
fi

echo "NEXORA: DEADFALL Android runtime smoke passed"

# Closed Beta tester guide

## Build

Expected build: `NEXORA: DEADFALL 0.9.0-beta.1`.

Use only the APK/AAB delivered through the official closed-beta channel. Do not redistribute room codes, APKs or test credentials outside the invited group.

## What to test

1. Launch and complete Mission 01.
2. Start/continue Mission 02 and verify checkpoint recovery after a forced failure.
3. Join a 2–4 player room and play several Horde waves.
4. Test DOWNED, revive and bleedout.
5. Disconnect/reconnect within the reconnect grace window.
6. Try Wi-Fi and mobile data where practical.
7. Record noticeable stutter, overheating, visual corruption, input failures or audio failures.

## Bug report essentials

Include:

- build version;
- phone model;
- Android version;
- selected quality tier;
- solo or Squad and player count;
- mission/wave/objective;
- exact reproduction steps;
- whether it reproduces again;
- screenshot/video where useful.

For a developer-assisted Android diagnostic bundle, `scripts/beta/collect_android_report.sh` captures device properties, package info, memory/thermal state and logcat through ADB.

## Privacy

Do not include passwords, private account credentials or unrelated personal content in bug reports. The in-game beta runtime intentionally filters token/password/host/address fields from its local breadcrumb data.

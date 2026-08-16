# Android compatibility matrix

Use one row per physical device/build combination. Do not mark Phase 9 physical compatibility complete until representative low/mid/high devices have actual measurements.

| Date | Build | Manufacturer / model | SoC | GPU | RAM | Android / API | Resolution | Tier | FPS p50 | FPS 1% low | Peak RAM | Thermal after 20m | Wi-Fi | Mobile data | Campaign | 4-player Squad | Reconnect | Crash/ANR | Result |
|---|---|---|---|---|---:|---|---|---|---:|---:|---:|---|---|---|---|---|---|---|---|
| | 0.9.0-beta.1 | | | | | | | | | | | | | | | | | | |

## Minimum test set

- At least one lower-memory Android device.
- At least one current mid-range Android device.
- At least one high-end Android device.
- Both major mobile GPU families where available (Adreno and Mali).
- Wi-Fi and mobile-data sessions.
- Solo Campaign and a four-player Squad/Horde session.
- Background/foreground, Wi-Fi↔mobile-data transition, reconnect and 20+ minute thermal soak.

## Pass notes

Record observed behavior; do not infer performance from specifications alone. A device is not considered compatible merely because the APK installs.

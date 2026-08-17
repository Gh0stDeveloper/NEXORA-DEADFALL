# Android compatibility matrix

Use one row per physical device/build combination. Do not mark physical compatibility complete until representative low/mid/high devices have actual measurements.

## Current closed-beta candidate

- App version: `0.9.0-beta.3`
- Version code: `900003`
- Network protocol: `2`
- Content version: `1`
- Accepted client range: `900003–900999`
- Accepted server range: `900003–900999`
- Target Android API: `36`
- Maximum players: `4`

Beta.3 intentionally rejects beta.2 gameplay clients/servers. It is the first candidate containing the authoritative rifle/pistol/machete loadout, replicated ammo pickups, revised mobile HUD, sprint toggle, recoverable match-loading flow, Game Over restart hardening, model normalization and the day/night presentation pass. The MTU-safe FastLZ transport framing remains protocol `2`; the version-code compatibility floor prevents old gameplay clients from entering beta.3 matches.

## Imported 3D animation capability

- Runtime visual height is normalized independently from authoritative gameplay colliders/hitboxes.
- Animated GLBs must expose at least one non-`RESET` runtime animation.
- Semantic names (`idle`, `walk`, `run`, `attack`, `hurt`, `death`, etc.) are preferred and mapped automatically when present.
- Generic-only animation names are accepted in `generic_fallback` mode only when a single neutral-looking usable clip exists. This prevents bind/T-pose without guessing among multiple unlabeled or clearly action/death clips.
- `operator_02` currently imports the usable generic clip `mixamo_com`; `zombie_animated` is inspected with `nexora-deadfall test-models` before pinning aliases.
- Dedicated/headless server processes do not instantiate presentation GLBs.

| Date | Build | Manufacturer / model | SoC | GPU | RAM | Android / API | Resolution | Tier | FPS p50 | FPS 1% low | Peak RAM | Thermal after 20m | Wi-Fi | Mobile data | Campaign | 4-player Squad | Reconnect | Crash/ANR | Result |
|---|---|---|---|---|---:|---|---|---|---:|---:|---:|---|---|---|---|---|---|---|---|
| | 0.9.0-beta.3 | | | | | | | | | | | | | | | | | | |

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

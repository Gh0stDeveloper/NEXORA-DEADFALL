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
- A GLB that exposes only a generic imported animation name can run in `generic_fallback` presentation mode. The clip is evaluated immediately so the model does not remain in bind/T-pose, but DEADFALL does not falsely classify that generic clip as a verified gameplay semantic.
- `operator_02` (Animated Character Base by J-Toastie) currently imports a usable generic clip named `mixamo_com`; it therefore uses `generic_fallback` until the source asset exposes distinguishable clips or an explicit verified mapping is available.
- `zombie_animated` (Animated Zombie by Quaternius) is inspected by `nexora-deadfall test-models`; its runtime inventory is printed before semantic aliases are pinned.
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

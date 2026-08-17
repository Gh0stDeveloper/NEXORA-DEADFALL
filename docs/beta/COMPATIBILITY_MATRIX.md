# Android compatibility matrix

Use one row per physical device/build combination. Do not mark physical compatibility complete until representative low/mid/high devices have actual measurements.

## Current closed-beta candidate

- App version: `0.9.0-beta.4`
- Version code: `900004`
- Network protocol: `2`
- Content version: `1`
- Accepted client range: `900004–900999`
- Accepted server range: `900004–900999`
- Target Android API: `36`
- Maximum players: `4`

Beta.4 intentionally rejects beta.3 gameplay clients/servers so physical acceptance is performed only with the presentation/performance candidate. It carries forward the authoritative rifle/pistol/machete loadout, replicated ammo pickups, mobile HP/ammo HUD, sprint toggle, recoverable matchmaking/loading flow, Game Over restart hardening and day/night cycle, and adds the Lobby 2.0 presentation pass, GLB animation capability handling, exact Quaternius zombie animation aliases, headless visual suppression, mobile render-scale/LOD/MSAA/FPS tuning and zombie visual-distance culling. The MTU-safe FastLZ transport framing remains protocol `2`.

## Imported 3D animation capability

- Runtime visual height is normalized independently from authoritative gameplay colliders/hitboxes.
- Animated GLBs must expose at least one non-`RESET` runtime animation.
- Semantic names (`idle`, `walk`, `run`, `attack`, `hurt`, `death`, etc.) are preferred and mapped automatically when present.
- Generic-only animation names are accepted in `generic_fallback` mode only when one neutral-looking usable clip exists; multiple unlabeled or clearly action/death clips are never guessed.
- `operator_02` currently exposes only the usable generic clip `mixamo_com`; it is used as a safe animated fallback to avoid bind/T-pose but is not falsely labeled as separate locomotion/combat clips.
- `zombie_animated` (Quaternius) is pinned to the verified runtime clips: `Zombie|ZombieIdle`, `Zombie|ZombieWalk`, `Zombie|ZombieRun`, `Zombie|ZombieCrawl` and `Zombie|ZombieBite`.
- Quaternius currently has no separately verified `hurt` or `death` clip in this GLB; those states retain the existing fallback presentation until compatible clips are added.
- Model validation prints `DEADFALL_MODEL_CAPABILITY`, `DEADFALL_MODEL_ANIMATION_READY` and `DEADFALL_MODEL_SEMANTICS` before acceptance.
- Dedicated/headless server processes do not instantiate presentation GLBs.

## Mobile presentation budgets

- `SMOOTH`: render scale 0.65, 30 FPS target, aggressive mesh LOD, MSAA off, zombie visuals roughly 52 m.
- `STANDARD`: render scale 0.90, 45 FPS target, medium mesh LOD, MSAA off, zombie visuals roughly 72 m.
- `ULTRA`: render scale 1.00, 60 FPS target, normal mesh LOD, MSAA 2x, zombie visuals roughly 96 m.
- `ULTRA_HD`: render scale 1.00, 60 FPS target, high-detail mesh LOD, MSAA 4x, zombie visuals roughly 128 m.
- These are runtime budgets, not claimed measured performance. Physical-device FPS/thermal acceptance still has to be recorded below.

| Date | Build | Manufacturer / model | SoC | GPU | RAM | Android / API | Resolution | Tier | FPS p50 | FPS 1% low | Peak RAM | Thermal after 20m | Wi-Fi | Mobile data | Campaign | 4-player Squad | Reconnect | Crash/ANR | Result |
|---|---|---|---|---|---:|---|---|---|---:|---:|---:|---|---|---|---|---|---|---|---|
| | 0.9.0-beta.4 | | | | | | | | | | | | | | | | | | |

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

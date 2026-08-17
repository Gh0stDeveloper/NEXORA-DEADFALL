# Android compatibility matrix

Use one row per physical device/build combination. Do not mark physical compatibility complete until representative low/mid/high devices have actual measurements.

## Current closed-beta candidate

- App version: `0.9.0-beta.5`
- Version code: `900005`
- Network protocol: `2`
- Content version: `1`
- Accepted client range: `900005–900999`
- Accepted server range: `900005–900999`
- Target Android API: `36`
- Maximum players: `4`

Beta.5 intentionally rejects beta.4 and older clients/servers because the dedicated-match lifecycle contract changed even though the wire protocol remains `2`. The candidate retains the beta.4 presentation/performance work and adds ticket-scoped authoritative reconnect, child-process heartbeat supervision, frozen-process detection, match TTL/reaping, authoritative match outcomes, coordinated return to lobby and lifecycle metrics exposed through the safe health endpoint.

### Beta.5 lifecycle acceptance contract

- A private 256-bit admission ticket remains scoped to exactly one match and one guest identity.
- If that client loses ENet connectivity, the server reserves its authoritative entity/slot/state for the reconnect grace window; the client never uploads trusted HP, position, ammo or hit state during recovery.
- The Android client retries reconnect for up to 42 seconds with bounded attempts. A successful reconnect must restore the same server-owned entity state rather than spawning an unrelated player.
- Every isolated match process writes a local heartbeat every 2 seconds. The parent orchestrator treats a live PID with a stale heartbeat as frozen and reaps it.
- Match children have startup/empty/runtime TTLs, and terminal children are reaped if they do not exit after result delivery.
- `VICTORY`, `DEFEAT` and `ABORTED` outcomes are produced by the authoritative child process, sent to connected peers and mirrored through local IPC for the parent orchestrator.
- On terminal result, the parent unlocks the squad and every connected Android client returns to a refreshed lobby after the result screen or its automatic timeout.
- Public `/v1/health` may expose aggregate lifecycle counters and watchdog settings, but never private tickets, per-player identities, child PIDs or match configuration paths.

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

| Date | Build | Manufacturer / model | SoC | GPU | RAM | Android / API | Resolution | Tier | FPS p50 | FPS 1% low | Peak RAM | Thermal after 20m | Wi-Fi | Mobile data | Campaign | 4-player Squad | Ticket reconnect | Result → lobby | Crash/ANR | Result |
|---|---|---|---|---|---:|---|---|---|---:|---:|---:|---|---|---|---|---|---|---|---|---|
| | 0.9.0-beta.5 | | | | | | | | | | | | | | | | | | | |

## Minimum test set

- At least one lower-memory Android device.
- At least one current mid-range Android device.
- At least one high-end Android device.
- Both major mobile GPU families where available (Adreno and Mali).
- Wi-Fi and mobile-data sessions.
- Solo Campaign and a four-player Squad/Horde session.
- A deliberate disconnect/reconnect during an active match, including at least one Wi-Fi↔mobile-data transition where practical.
- One authoritative victory/defeat result with all connected squad members returning to the same unlocked lobby.
- Background/foreground and 20+ minute thermal soak.

## Pass notes

Record observed behavior; do not infer performance from specifications alone. A device is not considered compatible merely because the APK installs. Beta.5 lifecycle acceptance remains pending until the VPS gates, signed APK deployment and physical multi-device tests are complete.

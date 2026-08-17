# Android compatibility matrix

Use one row per physical device/build combination. Do not mark physical compatibility complete until representative low/mid/high devices have actual measurements.

## Current Closed Beta

- App version: `0.9.0-beta.5`
- Version code: `900005`
- Network protocol: `2`
- Content version: `1`
- Accepted client range: `900005-900999`
- Accepted server range: `900005-900999`
- Target Android API: `36`
- Maximum players: `4`

Beta.5 intentionally rejects beta.4 and older clients/servers because the dedicated-match lifecycle contract changed even though the wire protocol remains `2`.

## Automated/production status

The beta.5 VPS validation and production deployment are complete at runtime anchor:

```text
f402f1696c0438447d76236122a5d82101a94cc0
```

Confirmed:

- current beta.5 automated gates passed;
- full VPS `--force` completed;
- Android Release APK exported;
- APK Signature Scheme v2 verified;
- one signer verified;
- APK published through the stable download path;
- localhost control/social/match API validated;
- HTTPS API validated.

What remains in this matrix is **physical-device acceptance and measured behavior**.

## Beta.5 lifecycle acceptance contract

- A private 256-bit admission ticket is scoped to one match/member identity.
- If ENet connectivity is lost, the server reserves the authoritative entity/slot/state for reconnect rather than accepting client-provided recovery state.
- Android retries reconnect for up to 42 seconds with at most 10 attempts.
- A successful reconnect must restore the same server-owned entity/state.
- Every isolated match process writes a local heartbeat every 2 seconds.
- The parent treats a live PID with stale heartbeat as frozen and reaps it.
- Match children have startup/empty/runtime TTLs and terminal reaping.
- After the first authoritative player admission the lifecycle is monotonic `READY -> IN_MATCH`; a temporary zero-connected-player reconnect gap does not make the match conceptually READY again.
- `VICTORY`, `DEFEAT` and `ABORTED` are produced by the authoritative match process.
- On terminal result, clients display the result and return to a refreshed/unlocked squad lobby.
- Public `/v1/health` may expose aggregate lifecycle counters/watchdog settings, never private tickets, identities, match IDs, child PIDs or private config paths.

## Imported 3D animation capability

- Runtime visual height is normalized independently from authoritative colliders/hitboxes.
- Animated GLBs must expose at least one non-`RESET` runtime animation.
- Semantic names are preferred and mapped when present.
- Generic-only names are accepted as `generic_fallback` only when a safe neutral usable clip exists.
- `operator_02` currently exposes only `mixamo_com`; it prevents bind/T-pose but is not treated as separate locomotion/combat clips.
- Quaternius mappings are pinned to:
  - `Zombie|ZombieIdle`
  - `Zombie|ZombieWalk`
  - `Zombie|ZombieRun`
  - `Zombie|ZombieCrawl`
  - `Zombie|ZombieBite`
- Quaternius has no separately verified Hurt/Death clip in the current asset.
- Dedicated/headless processes do not instantiate presentation GLBs.

## Mobile presentation budgets

These are configured runtime targets, not measured claims:

- `SMOOTH`: render scale 0.65, target 30 FPS, aggressive mesh LOD, MSAA off, zombie visuals ~52 m.
- `STANDARD`: render scale 0.90, target 45 FPS, medium mesh LOD, MSAA off, zombie visuals ~72 m.
- `ULTRA`: render scale 1.00, target 60 FPS, normal mesh LOD, MSAA 2x, zombie visuals ~96 m.
- `ULTRA_HD`: render scale 1.00, target 60 FPS, high-detail mesh LOD, MSAA 4x, zombie visuals ~128 m.

Tune only after collecting physical measurements.

## Physical test matrix

| Date | Build | Manufacturer / model | SoC | GPU | RAM | Android / API | Resolution | Tier | FPS p50 | FPS 1% low | Peak RAM | Thermal after 20m | Wi-Fi | Mobile data | Solo Campaign | Duo | 3-player | 4-player | Ticket reconnect | Result -> lobby | Crash/ANR | Result / notes |
|---|---|---|---|---|---:|---|---|---|---:|---:|---:|---|---|---|---|---|---|---|---|---|---|---|
| | 0.9.0-beta.5 | | | | | | | | | | | | | | | | | | | | | |

## Minimum physical test set

- At least one lower-memory Android device.
- At least one current mid-range Android device.
- At least one high-end Android device where available.
- Both Adreno and Mali where practical.
- Wi-Fi and mobile-data sessions.
- Solo Campaign gameplay.
- Duo public-Internet session.
- Three-player session.
- Four-player Squad/Horde session.
- Deliberate disconnect/reconnect during an active match.
- Prefer one Wi-Fi <-> mobile-data transition where practical.
- One authoritative victory/defeat result with all connected squad members returning to the unlocked lobby.
- Background/foreground behavior.
- 20+ minute thermal soak.

## Pass notes

Record observed behavior rather than inferring from device specifications. APK installation alone is not a compatibility pass.

Beta.5's automated/VPS deployment gate is complete. The current blocker to marking beta.5 fully accepted is the physical matrix above.
# NEXORA: DEADFALL — Current Status

Last updated: 2026-08-17.

This file is the short operational source of truth for the project. For the complete development sequence read `docs/ROADMAP.md`; for a new-chat continuation read `docs/HANDOFF_BETA_5.md`.

## Repository state

- Repository: `Gh0stDeveloper/NEXORA-DEADFALL`
- Active development branch: `agent/bootstrap-deadfall`
- Draft PR: `#1`
- PR policy: keep it open and Draft; do not merge unless the user explicitly authorizes the merge.
- Engine: Godot `4.6.3-stable`.
- Android target API: `36`.
- Current Closed Beta: `0.9.0-beta.5` / versionCode `900005`.
- Network protocol: `2`.
- Content version: `1`.
- Maximum party size: `4`.

## Last verified production deployment

Runtime deployment anchor:

```text
f402f1696c0438447d76236122a5d82101a94cc0
```

The full VPS `--force` update completed successfully for beta.5. The important production results were:

- Godot/Closed Beta/Phase 11.3/Phase 12 gates passed before deployment.
- Android Release APK exported successfully.
- APK was verified with APK Signature Scheme v2.
- Exactly one signer was present.
- Stable APK was published as:
  `/var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk`.
- Published version: `0.9.0-beta.5`.
- Control/social/match API validated on localhost `127.0.0.1:24562`.
- The same API validated behind HTTPS through Nginx.
- Updater completed without replacing the persistent signing identity.

Documentation-only commits after the deployment anchor do not imply a new runtime deployment and do not require a rebuild by themselves.

## Known non-blocking build messages

The VPS may print:

```text
cannot connect to daemon at tcp:5037: Connection refused
```

This is the ADB daemon when no Android device is connected to the VPS. It is not a failed build gate.

Godot may also print editor/export cleanup notices such as orphan StringName or script-doc persistence warnings at process exit. Treat them as non-blocking unless they become crashes, parse/compile errors, export failures, or reproduce in gameplay.

## Completed product foundation

### Core gameplay

- Android-first FPS/TPS movement.
- Walk, sprint, jump, crouch and prone.
- Touch joystick/look region and mobile action controls.
- First-person, rear third-person and front third-person cameras.
- Persistent touch sensitivity.
- Flashlight and night readability baseline.
- Safe-area-aware mobile HUD.

### Combat

- Server/local authority abstraction shared by offline and online modes.
- NXR rifle.
- Pistol.
- Machete.
- Weapon selector/loadout.
- Finite magazine/reserve ammunition.
- Timed reload.
- Body hit zones and critical damage.
- Authoritative hitscan/damage/health/ammo online.
- Replicated authoritative weapon action sequences.
- Zombie ammo drops and authoritative pickups.

### Zombies, Horde and gore

- Walker, Runner, Crawler, Tank and Screamer archetypes.
- IDLE/SEARCH/CHASE/ATTACK/STAGGER/DEAD AI foundation.
- Navigation/perception and authoritative melee.
- Horde waves, scoring, population budgets and spawn safety.
- DOWNED/revive-aware Horde game-over rules.
- Dismemberment/gore pools and quality budgets.
- Game Over/Restart flow.

### Campaign

- `OutbreakDistrict` vertical slice.
- Mission 01 — First Signal.
- Mission 02 — Last Broadcast.
- Sequential campaign objective framework.
- Hardened checkpoint persistence/recovery.
- Dedicated-server campaign authority.
- Day/night cycle with headless-safe behavior.

## Multiplayer and social status

### Squad/social

Implemented:

- guest identity and persistent guest account;
- server-verified unique username;
- server-generated public player ID;
- friends/direct messages foundation;
- Solo/Duo/Squad lobby formation;
- six-character squad codes;
- join/leave;
- leader-only kick/start rules;
- squad chat;
- selected-character synchronization;
- ping presentation;
- server-side party locking while a match is starting/running.

### Match orchestration

Implemented and automated-tested:

1. leader starts an online party match through the HTTPS control API;
2. parent MatchOrchestrator allocates one child process and one UDP port for the party;
3. every member receives the same `match_id`, host and port;
4. every member receives a different private 256-bit admission ticket;
5. child process starts a dedicated Campaign instance;
6. child publishes a real readiness marker;
7. no-ticket/invalid-ticket clients are rejected;
8. valid tickets restore only their assigned identity/entity;
9. the process reports heartbeat/result IPC back to the parent.

Production dynamic match range:

```text
UDP 24600-24749
```

### Beta.5 lifecycle

Implemented:

- ticket-scoped reconnect;
- Android reconnect window: 42 seconds / max 10 attempts;
- same authoritative entity/slot restored after reconnect;
- authoritative HP/position/ammo/loadout recovery;
- 2-second child heartbeat;
- live-but-frozen child detection;
- startup/empty/absolute runtime TTLs;
- terminal child reaping;
- monotonic `READY -> IN_MATCH` lifecycle after the first authoritative admission;
- `VICTORY`, `DEFEAT`, `ABORTED` authoritative results;
- result UI;
- automatic/manual return to refreshed squad lobby;
- aggregate lifecycle metrics on `/v1/health` without exposing tickets, identities, match IDs, PIDs or private paths.

The real Linux orchestration test has proven:

- missing ticket rejection;
- leader admission;
- graceful ENet disconnect;
- reconnect using the same ticket;
- same entity ID restoration;
- reconnect counter increment;
- second party member admission;
- child-process cleanup.

## 3D assets and animation status

Vendored source repository:

```text
Gh0stDeveloper/Objetos3D
pinned commit: 28ea7a10a18fbe05a91fb3d920678991fff4afef
```

Canonical mappings:

- `operator_01.glb` — Daren low-poly survival character.
- `operator_02.glb` — J-Toastie Animated Character Base.
- `zombie_animated.glb` — Quaternius Animated Zombie.
- `zombie_static.glb` — cs_aaron Zombie.

Runtime normalization scales/centers models independently from authoritative colliders.

Verified animation capabilities:

- `operator_02`: one generic clip, `mixamo_com`; safe fallback only. It prevents bind/T-pose but does not provide separate Idle/Walk/Run/Attack/Death semantics.
- Quaternius:
  - idle -> `Zombie|ZombieIdle`
  - walk -> `Zombie|ZombieWalk`
  - run -> `Zombie|ZombieRun`
  - crawl -> `Zombie|ZombieCrawl`
  - attack -> `Zombie|ZombieBite`
- Separate verified Quaternius Hurt/Death clips are still missing.

## Mobile presentation/performance already implemented

- Lobby 2.0 visual pass.
- Central 3D character stage.
- Own procedural operator models with MARA/DANTE palette variants, normalized visual height, used by default in lobby and gameplay.
- Party rail with 2/4 visible procedural avatars, identity, leader and ping status.
- Procedural first-person rifle/pistol/machete view models; the infinite machete remains server-authoritative.
- Procedural zombie presentation around 1.60 m for the base walker, with aligned fallback visuals/hitboxes and gore forwarding.
- Lobby turntable preview; the external GLB path remains only as optional compatibility fallback (runtime presenters use USE_EXTERNAL_MODELS := false).
- Quality tiers controlling render scale, mesh LOD, MSAA and FPS target.
- Zombie visual distance culling by quality tier.
- Presentation GLBs disabled on dedicated/headless processes.

## Android build/deployment hardening already implemented

- Persistent release keystore under `/etc/nexora-deadfall/signing/`.
- Normal updates never regenerate that signing identity.
- Generated Android template sanitizer removes only the four redundant Godot Manifest merger `tools:replace` directives.
- `android.suppressUnsupportedCompileSdk=36` is applied reproducibly.
- Android builder uses the Godot-compatible toolchain and Build Tools 36.1.0 baseline.
- Closed Beta GitHub workflow derives version/versionCode from `BuildInfo.gd` rather than hard-coded beta.1 metadata.
- VPS update classification rebuilds the APK when application/shared build code changes.

## Production network/VPS layout

Public/external:

- TCP 80 — HTTP/web.
- TCP 443 — HTTPS/web/API.
- UDP 24560 — base/legacy gameplay service.
- UDP 24600-24749 — orchestrated dedicated match instances.

Internal/limited:

- TCP 24561 — room directory where needed.
- TCP 24562 — control/social/match API; localhost only, published externally only through Nginx HTTPS.

Important paths:

```text
/opt/nexora-deadfall
/var/lib/nexora-deadfall
/etc/nexora-deadfall
/var/www/nexora-deadfall
/var/log/nexora-deadfall
/usr/local/bin/nexora-deadfall
```

## Current download portal

Current implementation is a small Next.js App Router application under:

```text
web/download-site
```

The current home page reads `/var/www/nexora-deadfall/release.json` dynamically and displays:

- current version;
- APK size;
- SHA-256;
- download button;
- Android/Closed Beta notice.

This works, but it is intentionally simple and is scheduled for a product/UI upgrade. See `docs/DOWNLOAD_PORTAL_PLAN.md`.

## Current presentation patch

The active branch now contains a presentation-only multiplayer/lobby pass that is not a new deployed beta runtime yet:

- Duo/Squad slots render each admitted member's selected operator as a small procedural 3D avatar.
- Runtime player/zombie presenters default to first-party procedural geometry; external GLBs are not loaded by default.
- Player visual height is kept below the authoritative standing collider; the base zombie target is about 1.64 m.
- Match assignment validation accepts only the production UDP range 24600-24749 and 64-character hexadecimal tickets.
- Mobile touch buttons now use the explicit router path without duplicate emulated clicks; the previously malformed `TouchActionButton.gd` draw branch was repaired.
- These changes still require the real VPS gates and physical Android acceptance before any beta runtime publication.

## Immediate next gate: physical beta.5 acceptance

Automated production deployment is complete. The next functional gate is real-device acceptance, not another version bump.

Required sequence:

1. Solo Android smoke:
   login -> lobby -> character preview -> Campaign -> movement -> sprint -> HP/ammo HUD -> rifle/pistol/machete -> ammo pickup -> zombies -> day/night -> Game Over/Restart.
2. Duo over the public Internet.
3. Deliberate disconnect/reconnect during an active match; same player/entity/state must return.
4. Validate result screen and both clients returning to the same unlocked lobby.
5. Repeat with 3 players.
6. Repeat with 4 players.
7. Prefer at least two different network paths (Wi-Fi and mobile data).
8. Record FPS/memory/thermal observations where possible.
9. Inspect server lifecycle logs while testing dynamic ports/process creation and cleanup.

Do not call beta.5 physically accepted until these tests are completed.

## Work still pending after physical acceptance

Priority depends on physical-test findings, but planned work includes:

- fix any blocker discovered by beta.5 physical testing before adding unrelated systems;
- improve the download portal and add version-history/changelog navigation;
- finish full settings screen and HUD editor;
- add production audio buses, weapon/zombie/ambient/music/UI audio;
- improve/expand environment art and level dressing;
- add/retarget full player locomotion/combat/death animations;
- add verified zombie Hurt/Death presentation;
- deeper Android performance/thermal optimization based on measurements;
- reconnect/latency edge-case soak and abuse hardening;
- wider compatibility matrix;
- later content expansion: missions, weapons, zombie variants, loot/progression and map content;
- voice chat remains deferred until core co-op and performance are stable.

## Rule for the next development chat

Do not start by re-planning the project from zero. Fetch the current branch, read:

1. `docs/HANDOFF_BETA_5.md`
2. `docs/CURRENT_STATUS.md`
3. `docs/ROADMAP.md`
4. `docs/DOWNLOAD_PORTAL_PLAN.md`
5. `docs/beta/RELEASE_HISTORY.md`

Then continue from the first unchecked item in the immediate plan.
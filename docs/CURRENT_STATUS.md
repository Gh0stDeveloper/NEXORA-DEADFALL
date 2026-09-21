# NEXORA: DEADFALL — Current Status

Last updated: 2026-09-21.

This file is the short operational source of truth for the project. For the complete development sequence read `docs/ROADMAP.md`; for a new-chat continuation read `docs/HANDOFF_CITY_SIMULATION.md`.

## Repository state

- Repository: `Gh0stDeveloper/NEXORA-DEADFALL`
- Installation/update branch: `main`.
- Integration source: `agent/bootstrap-deadfall`, PR `#1`.
- The owner explicitly authorized merging PR #1 into main on 2026-09-16. This supersedes the earlier instruction to keep that PR Draft. Future merges still require authorization.
- Engine: Godot `4.6.3-stable`.
- Android target API: `36`.
- Deployed Closed Beta: beta.5; owner confirmed the portal/main update works.
- Current source: `0.9.0-beta.6` / versionCode `900006`.
- The owner merged PR `#16` into main at `668347bb8444380bc2245fdcbdf01c5cd968b6dc`.
- The VPS passed the beta.6 Godot gates, then stopped at release history publication before portal build / Android export. The last confirmed published APK remains beta.5.
- Publication fix: `agent/fix-beta6-release-transition`; merge its PR before retrying the main updater.
- Network protocol: `2`.
- Candidate content version: `2` (update all clients and server together).
- Maximum party size: `4`.

## Release history update failure — beta.6

The source catalog advances to beta.6 before the updater builds Android, so the
existing `release.json` still describes beta.5. The Python publisher supported
`--keep-published-version`, but that option was omitted from the production portal
build script in PR #16. The fix adds it to `scripts/build/build_download_site.sh`;
the Android publisher keeps its strict version check after APK export.

The regression now executes the publisher calls extracted from both production
scripts instead of constructing a separate command with the correct flag. It
reproduces the failure using the caller from main, then passes with the fix:
fresh installation, previous APK preservation, interrupted-build retry, corrupt
manifest rejection, strict final publication and subsequent portal rebuild.
Installer checks and the full standalone portal build/routes smoke passed locally.
No new signed APK or completed VPS deployment is claimed yet.

## City/simulation source — beta.6

A shared 192 × 192 m city now contains fifteen enterable buildings, streets,
curbs, natural surfaces, vegetation, wrecks and client-side fire. VALERIA replaces
the previous operator_01 presentation; DANTE and account character IDs stay stable.
Dedicated actors/maps instantiate no visual, camera, light or audio nodes.
Server-authoritative collision, navigation and AI remain active. Horde pursuit
fixes the navigation height mismatch, distant spawns, curbs and freed targets.

Source checkpoint: `d74038c8e6d7621e175c3b543a50fba750c09518`. Local gates passed.
Remote Actions failed before job execution (runner ID 0, empty steps, no logs);
no remote green check or Android artifact is claimed.

See HANDOFF_CITY_SIMULATION.md for phase checklists, measured local results,
known physical acceptance limits and the branch update command.

## Tactical presentation phase — implemented and locally validated

The recovered redesign now includes threaded visual boot/loading, robust verified
guest access/retry, a tactical amber/cyan lobby and shared Solo/Duo/Squad stage,
operator/arsenal/settings panels, fitted skinned operators and zombie variants,
detailed visible first-person weapons, and original music/ambience/effects with
persistent volume controls. Hidden stages stop rendering and headless servers skip
presentation work.

All 16 local regression/integration gates passed with Godot 4.6.3. A rendered
end-to-end test also passed real local HTTP account registration/retry, lobby and
formation panels, saved operator/audio choices, Solo Campaign and all three
weapons. The new graphical CI step retains logs/captures. See
`docs/HANDOFF_TACTICAL_PRESENTATION.md` for exact scope and reproduction commands.

This is a source delivery on the active branch. A new Android APK, physical-device
acceptance and production deployment remain pending. It does not change the last
verified production deployment below. See `docs/HANDOFF_PORTAL_MAIN.md` for the
subsequent portal fix and authorized integration into main.

## Portal deployment fix and main integration

The user reported that the VPS passed template, compile, presentation assets,
account/loading, gameplay/mobile, lifecycle, project, beta and Phase 11 gates at
`eea4df4`, then stopped before Android export with a portal 404. The app exposed
`/versions` while all links and deployment checks expected `/versiones`.

The corrected source uses `/versiones` with redirects for old English URLs,
accepts nullable historical version codes in the live catalog, and avoids tracing
external runtime history into the standalone bundle. CI now exercises the copied
standalone server using the production updater's route validator, including live
catalog/SHA changes, public/static assets and missing-version 404s.

The owner subsequently confirmed that this update works. Its exact deployed SHA
was not supplied. The historical full-log anchor below is retained for traceability.
Beta.6 is a separate candidate and must not be confused with that deployed update.

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

- Original hangar artwork, tactical theme, icons and Rajdhani font.
- Threaded boot and staged account/match loading with usable failure/retry flows.
- Shared 3D Solo/Duo/Squad stage, member identity, vacancies, leader/ping status.
- Rotating operator/weapon inspection, social dialogs and persistent settings.
- MARA/DANTE skinned models with fitted equipment and procedural limb/weapon IK.
- Rifle, pistol and machete with first-person hands, recoil and muzzle feedback.
- Animated zombie variants with persistent limb removal and native fallback.
- Original music, ambience, weapon/UI/footstep/zombie cues; bounded voices and
  persistent Master/Music/SFX/UI/Ambience buses.
- Cached/batched geometry, hidden-stage suspension, render/animation budgets and
  quality tiers; presentation and audio disabled on dedicated/headless processes.

The legacy `USE_EXTERNAL_MODELS := false` flag now selects the character factory,
which itself uses the normalized skinned models; it does not disable GLB loading.

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

The current portal reads `/var/www/nexora-deadfall/releases.json` dynamically and displays the current release, history, detail routes, compatibility and beta information. The build pipeline consumes `release.json` as the current APK manifest and merges its size/SHA-256 into the durable catalog.

The stable download path remains:

- `/downloads/NEXORA-DEADFALL-latest.apk`.

This works, but it is intentionally simple and is scheduled for a product/UI upgrade. See `docs/DOWNLOAD_PORTAL_PLAN.md`.

### Phase 13 source implementation (not yet deployed)

The active branch now contains the contained portal/history implementation:

- tracked structured release records at `web/download-site/src/data/releases.json`;
- schema validation and atomic publication of `/var/www/nexora-deadfall/releases.json`;
- shared responsive header with hamburger drawer;
- current-release home card, version timeline, version detail routes, compatibility and beta information routes;
- Current/Superseded/Withdrawn status presentation, changelog sections, APK size and SHA-256 fields;
- web-only download-portal smoke covering build, routes, clean 404 and history uniqueness;
- updater classification keeps `web/download-site/**` and `build_download_site.sh` independent from Android rebuilds.

This source pass is not a new Android runtime deployment. The VPS web-only build, HTTPS route check and mobile-browser validation remain pending.

## Current source and release distinction

The tactical presentation phase is locally tested source. Export a fresh Android
build through the existing validated pipeline, then repeat the physical tests
below. The screenshots and Linux tests do not certify Android performance or
establish a newly deployed beta runtime.

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
- finish remaining HUD editor customization and physical touch usability;
- validate the new audio mix on actual Android speakers/headphones;
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
6. `docs/HANDOFF_TACTICAL_PRESENTATION.md`

Then continue from the first unchecked item in the immediate plan.

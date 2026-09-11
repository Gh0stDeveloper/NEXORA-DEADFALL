# NEXORA: DEADFALL — Persistent Project Context

Last updated: 2026-09-11.

This document records the durable architecture and working rules for future development sessions. The fastest continuation point is `docs/HANDOFF_BETA_5.md`; the operational state is `docs/CURRENT_STATUS.md`.

## Product identity

- Project: **NEXORA: DEADFALL**
- Brand/developer: **Ghost Developer / Nexora**
- Genre: 3D zombie survival shooter
- Primary platform: Android ARM64, landscape
- Engine: **Godot 4.6.3**
- Rating target: adults / +18 because of graphic violence, gore/dismemberment and strong language
- Online backend: own Ubuntu 24.04 VPS running headless Godot dedicated servers
- Maximum online squad: 4 players
- Current Closed Beta: `0.9.0-beta.5 / 900005`
- Network protocol: `2`
- Target Android API: `36`

## Repository workflow

- Repository: `Gh0stDeveloper/NEXORA-DEADFALL`
- Active branch: `agent/bootstrap-deadfall`
- Draft PR: `#1`
- Keep PR #1 open and Draft until the user explicitly authorizes a merge.
- The developer commonly works from a phone plus VPS, so reproducible source automation is mandatory.
- Do not solve production problems with undocumented VPS-only edits. Fix the repository/deployment scripts so a clean installation receives the same correction.
- GitHub Actions is part of the intended CI flow, but red runs with `steps=null` caused by account/repository billing-spending rejection are not source-test results. The VPS gates remain authoritative while that condition exists.

## Last deployed runtime

The user confirmed a complete beta.5 `--force` deployment at:

```text
f402f1696c0438447d76236122a5d82101a94cc0
```

That deployment completed:

- current-head validation gates;
- Android Release export;
- APK Signature Scheme v2 verification;
- one signer verification;
- stable APK publication;
- localhost control/social/match API validation;
- HTTPS API validation.

Published APK path:

```text
/var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk
```

Documentation commits after the runtime anchor are not new runtime releases by themselves.

## Runtime authority model

Offline and online gameplay share the same gameplay implementation.

- Offline: local authority.
- Online: dedicated server authority.
- Clients are input/prediction/presentation endpoints.

Never trust online clients for:

- health;
- damage;
- hit results;
- ammunition;
- weapon cadence/reload completion;
- revive completion;
- zombie AI decisions;
- Horde decisions;
- campaign progression;
- match results;
- reconnect restoration state.

The server owns those states and sends snapshots/results to clients.

## Multiplayer architecture

Base/legacy services:

```text
24560/udp gameplay
24561/tcp room directory when needed
24562/tcp control/social/match API — localhost only
```

Public orchestrated matches:

```text
24600-24749/udp
```

Public web/API ingress:

```text
80/tcp
443/tcp
```

TCP 24562 must not be directly exposed. Nginx proxies the public HTTPS API to localhost.

### Party and match isolation

The authoritative social squad is separate from a dedicated gameplay process.

When the leader starts an online match:

1. the server snapshots the current party;
2. one `match_id` is created;
3. one free UDP port is allocated;
4. one dedicated child Godot process is launched;
5. every squad member receives the same match ID/host/port;
6. every member receives a different private 32-byte/64-hex admission ticket;
7. the child loads the admission record and writes a readiness marker;
8. knowing host/port without a valid ticket is insufficient to enter;
9. tickets are bound to their admitted member/identity.

### Network transport

- Godot MultiplayerAPI/ENet.
- Protocol v2.
- MTU-safe FastLZ snapshot transport.
- 900-byte unreliable chunks.
- prediction/reconciliation for local movement;
- interpolation for remote replicas;
- per-quality snapshot/relevance budgets;
- stale input neutralization.

## Beta.5 match lifecycle

Beta.5 layers `LifecycleMtuSafeNetworkSession.gd` on top of the MTU-safe transport.

Implemented behavior:

- ticket-scoped reconnect restores the same authoritative entity/slot/state;
- Android reconnect window: 42 seconds, max 10 attempts;
- child process writes heartbeat every 2 seconds;
- parent detects stale heartbeat/live-but-frozen child processes;
- startup, previously-started-empty and absolute-runtime timeouts;
- terminal result process reaping;
- lifecycle becomes monotonic `READY -> IN_MATCH` after the first authoritative admission and does not revert because everyone is temporarily reconnecting;
- authoritative result values: `VICTORY`, `DEFEAT`, `ABORTED`;
- clients receive result UI and return to a refreshed/unlocked lobby;
- `/v1/health` exposes aggregate lifecycle metrics only.

The real Linux orchestration regression has demonstrated no-ticket rejection, first admission, graceful disconnect, same-ticket reconnect to the same entity and a second member admission.

## Player/gameplay state

Already present:

- walk/sprint/jump/crouch/prone;
- virtual movement joystick and touch look;
- first-person/rear-third-person/front-third-person camera cycling;
- mobile controls with icon-based presentation;
- persistent sensitivity;
- flashlight;
- safe-area-aware HUD;
- HP/ammo/current weapon display;
- rifle;
- pistol;
- machete;
- weapon selector/loadout;
- finite magazine/reserve ammunition;
- timed reload;
- authoritative hitscan/melee/damage/ammo online;
- zombie ammo drops and authoritative pickups;
- Game Over/Restart.

## Zombie/Horde/gore state

Zombie archetypes:

- Walker;
- Runner;
- Crawler;
- Tank;
- Screamer.

Implemented foundations include navigation/perception, authoritative attacks, Horde waves/scoring/population budgets, spawn safety, DOWNED/revive-aware game-over rules and bounded gore/dismemberment pools.

## Campaign state

- `OutbreakDistrict` vertical slice.
- Mission 01 — First Signal.
- Mission 02 — Last Broadcast.
- REACH/KILL/SURVIVE/INTERACT/EXTRACT objective framework.
- checkpoint persistence and recovery.
- dedicated-server campaign authority.
- campaign replication/HUD.
- day/night cycle.

## Lobby/social state

Implemented:

- guest account/login flow;
- game-generated guest secret;
- server-side unique username;
- server-generated public player ID;
- friends/direct-message foundation;
- Solo/Duo/Squad selection;
- six-character party codes;
- join/leave;
- leader-only kick/start;
- squad chat;
- member/selected-character/ping presentation;
- central 3D character/operator preview;
- server-authoritative party lock while matchmaking/match is active.

## 3D model source and animation rules

Model source is vendored from private repository:

```text
Gh0stDeveloper/Objetos3D
commit 28ea7a10a18fbe05a91fb3d920678991fff4afef
```

Canonical runtime mappings:

- `operator_01.glb` — Daren low-poly survival character;
- `operator_02.glb` — J-Toastie Animated Character Base;
- `zombie_animated.glb` — Quaternius Animated Zombie;
- `zombie_static.glb` — cs_aaron Zombie.

Visual models are normalized independently from authoritative colliders/hitboxes.

Animation facts:

- `operator_02` exposes only `mixamo_com`; use it as a neutral generic fallback to prevent bind/T-pose, never claim it represents multiple semantic actions.
- Quaternius verified clips:
  - Idle `Zombie|ZombieIdle`
  - Walk `Zombie|ZombieWalk`
  - Run `Zombie|ZombieRun`
  - Crawl `Zombie|ZombieCrawl`
  - Attack `Zombie|ZombieBite`
- verified separate Hurt/Death animation clips remain pending.
- dedicated/headless processes do not instantiate presentation GLBs.

## Android presentation/performance

Implemented quality-tier controls include:

- render scale;
- mesh LOD threshold;
- MSAA;
- target FPS;
- zombie visual-distance culling.

These are configured budgets, not claimed physical-device benchmark results. Use real-device measurements to tune them.

## Android build/signing rules

- Persistent signing directory: `/etc/nexora-deadfall/signing/`.
- Never regenerate signing identity during normal updates.
- Generated Android template is sanitized reproducibly immediately before Manifest merge.
- Only the four known redundant Godot `tools:replace` attributes are removed.
- compileSdk 36 warning suppression is managed by build automation.
- current toolchain automation uses Build Tools 36.1.0 baseline.
- closed-beta workflow reads version/versionCode from `BuildInfo.gd`.

## VPS paths

```text
/opt/nexora-deadfall       repository checkout
/var/lib/nexora-deadfall  runtime/build/match state
/etc/nexora-deadfall      config + signing secrets
/var/www/nexora-deadfall  public APK/release metadata
/var/log/nexora-deadfall  service/build logs
/usr/local/bin/nexora-deadfall admin command
```

## Download portal

The current Next.js App Router portal lives at:

```text
web/download-site
```

It consumes the generated `releases.json` catalog for the current release, history, compatibility and detail pages. The current `release.json` is merged by the build pipeline so the catalog carries the published APK size and SHA-256.

A redesign is planned with:

- hamburger menu;
- durable version history;
- version detail routes;
- additions/fixes/changes/known limitations;
- compatibility/integrity information;
- current/superseded/withdrawn status.

See `docs/DOWNLOAD_PORTAL_PLAN.md`.

## Current priority

Automated beta.5 deployment is complete. The next real product gate is physical acceptance:

1. Solo Android.
2. Duo public Internet.
3. deliberate disconnect/reconnect within the beta.5 recovery window.
4. authoritative result and both clients returning to the same lobby.
5. three-player.
6. four-player.
7. FPS/RAM/thermal observations and compatibility matrix.

Critical physical blockers take priority over portal or feature expansion.

If physical beta.5 is usable, Phase 13 is the download portal/version-history upgrade. After that, planned blocks include full settings/HUD editor/audio, animation/art/content expansion and deeper multiplayer soak.

Voice chat remains intentionally deferred until core co-op and Android performance are stable.

## Documentation hierarchy

Current authoritative documents:

1. `docs/HANDOFF_BETA_5.md` — exact new-chat continuation point and prompt.
2. `docs/CURRENT_STATUS.md` — concise operational source of truth.
3. `docs/ROADMAP.md` — completed/pending work and phase order.
4. `docs/DOWNLOAD_PORTAL_PLAN.md` — portal redesign/version-history plan.
5. `docs/beta/RELEASE_HISTORY.md` — release index.
6. this file — durable architecture/product rules.

Historical documents such as `HANDOFF_PHASE_11_3.md` and `PHASE_11_PLAN.md` remain useful for historical decisions but no longer describe the current project state.
# NEXORA: DEADFALL — Beta.5 Handoff / New Chat Continuation

Last updated: 2026-09-11.

This is the authoritative continuation document for starting a new ChatGPT/Codex conversation. Read this before changing gameplay, networking, Android build, VPS deployment or the download portal.

## Repository and branch

- Repository: `Gh0stDeveloper/NEXORA-DEADFALL`
- Development branch: `agent/bootstrap-deadfall`
- Draft PR: `#1`
- Do not merge PR #1 unless the user explicitly requests a merge.
- Always fetch the current PR/branch again at the beginning of a new chat because documentation commits may have moved HEAD after this file was written.

## Production runtime anchor

The last full runtime deployment that the user confirmed successful is:

```text
f402f1696c0438447d76236122a5d82101a94cc0
```

Build deployed:

```text
NEXORA: DEADFALL 0.9.0-beta.5
versionCode 900005
channel closed_beta
protocol 2
content version 1
Android target API 36
```

Full `--force` deployment result:

- Android Gradle release export succeeded.
- APK Signature Scheme v2 verification succeeded.
- One signer.
- APK published to `/var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk`.
- localhost control/social/match API validated on `127.0.0.1:24562`.
- HTTPS-proxied API validated.
- update completed successfully.

Any commits after `f402f169...` that only change documentation do not mean runtime beta.5 has been redeployed.

## Important non-blocking VPS message

This is expected when no Android device is connected to the VPS:

```text
cannot connect to daemon at tcp:5037: Connection refused
```

Do not treat it as a failed gate by itself.

## Architecture invariants

- Offline and online gameplay share the same systems.
- Offline uses local authority.
- Online uses dedicated-server authority.
- Client never owns trusted HP, damage, hits, ammo, zombie decisions, revive completion, mission progression or reconnect recovery state.
- Server is Godot headless on Ubuntu 24.04.
- ENet is the gameplay transport.
- Maximum squad size is four players.
- Dynamic orchestrated matches use UDP `24600-24749`.
- Control/social API uses localhost TCP `24562` and must not be opened directly to the Internet.
- Nginx exposes the API through HTTPS.
- Persistent signing identity under `/etc/nexora-deadfall/signing/` must never be regenerated during normal updates.
- Any manual VPS fix must also be represented in repository source/automation so clean installs do not regress.

## What is already completed

### Gameplay

- walk/sprint/jump/crouch/prone;
- FPS/rear TPS/front TPS;
- touch joystick/look/mobile controls;
- persistent sensitivity;
- flashlight;
- HP/ammo/weapon HUD;
- sprint toggle;
- rifle + pistol + machete;
- selector/loadout;
- limited magazines/reserves;
- authoritative reload/fire/hit/damage;
- zombie ammo drops and authoritative pickups;
- Game Over/Restart;
- Horde waves/scoring;
- Campaign missions/checkpoints;
- day/night.

### Zombies/gore

- Walker/Runner/Crawler/Tank/Screamer;
- server-authoritative AI/combat;
- zombie replication/relevance budgets;
- gore/dismemberment pool budgets;
- crawler/limb/head gameplay effects.

### Lobby/social

- guest account/login;
- unique username server-side;
- public player ID;
- friends/direct message foundation;
- Solo/Duo/Squad lobby;
- party codes;
- join/leave;
- leader kick/start;
- squad chat;
- member/character/ping presentation;
- central 3D character stage;
- turntable preview;
- party state lock during match lifecycle.

### Models/animations

Vendor repo:

```text
Gh0stDeveloper/Objetos3D
commit 28ea7a10a18fbe05a91fb3d920678991fff4afef
```

Mappings:

- MARA/operator_01 -> Daren low-poly survival character.
- DANTE/operator_02 -> J-Toastie animated character base.
- animated zombie -> Quaternius.
- secondary zombie -> cs_aaron.

`operator_02` only exposes `mixamo_com`; use as neutral generic fallback, not fake semantic locomotion.

Quaternius verified clips:

```text
idle   Zombie|ZombieIdle
walk   Zombie|ZombieWalk
run    Zombie|ZombieRun
crawl  Zombie|ZombieCrawl
attack Zombie|ZombieBite
```

Hurt/Death clips still need compatible assets/retargeting.

### Networking / Phase 11.3

- party members get one shared `match_id` and dedicated child process;
- dynamic UDP allocation;
- one private 256-bit ticket per member;
- no-ticket admission rejected;
- host/port knowledge alone is insufficient;
- MTU-safe FastLZ snapshot chunks of 900 bytes;
- server-authoritative movement/combat/zombies/progression;
- prediction/reconciliation/interpolation;
- loading overlay with timeout/recovery;
- Lobby -> matchmaking -> dedicated child -> loading -> ticket admission -> spawn.

### Beta.5 / Phase 12 lifecycle

- same ticket can reconnect only to its assigned identity/entity;
- reconnect window 42 s / max 10 attempts on Android;
- server restores state; client does not upload trusted recovery state;
- child heartbeat every 2 s;
- parent watchdog for stale/frozen child;
- startup/empty/absolute TTLs;
- terminal-result reaping;
- monotonic `READY -> IN_MATCH` after first authoritative admission even if all players are temporarily reconnecting;
- authoritative `VICTORY` / `DEFEAT` / `ABORTED`;
- result screen;
- return to refreshed/unlocked lobby;
- safe aggregate lifecycle metrics.

Real orchestration regression already demonstrated:

```text
NoTicket -> match_ticket_required
Leader first join -> entity 101
Leader graceful disconnect -> reserved state
Leader same-ticket reconnect -> entity 101
DEADFALL_MATCH_RECONNECT_ACCEPTED count=1
Member join -> entity 102
```

## Active branch presentation update

The current branch adds a Duo/Squad lobby party rail with procedural avatars and procedural first-person weapon models. Player and zombie runtime presenters use own procedural geometry by default, with the existing external catalog retained only for optional compatibility fallback. The mobile touch button router was also repaired so action buttons emit once through the explicit touch path, including a corrected `TouchActionButton.gd` draw branch. This is source work after the last deployed beta.5 runtime and does not replace the required physical Android acceptance gate.

## Android/VPS build state

- Godot 4.6.3.
- JDK 17.
- Android API 36.
- Godot-compatible Android Gradle setup.
- Build Tools 36.1.0 baseline in current automation.
- generated Manifest sanitizer removes only four redundant `tools:replace` directives;
- unsupported compileSdk warning suppression is applied reproducibly;
- persistent keystore reused;
- updater classifies app/server/web/deploy changes;
- web-only changes should not rebuild the APK;
- application/shared build changes should rebuild the APK;
- `--tests-only` performs validation without changing the last successful deploy state;
- `--force` performs full gates/build/restart/publication/health checks.

## GitHub Actions caveat

GitHub Actions had been rejected before runner execution because of repository/account billing/spending status. Jobs with `steps=null` are not source test results. VPS gates remain the trustworthy automated validation environment until Actions actually executes runner steps again.

## Current portal

Path:

```text
web/download-site
```

The portal now reads the generated public `releases.json` catalog dynamically and falls back to the tracked source records during build/preview. The current `release.json` remains the machine-readable APK manifest consumed by the history publisher.

Planned upgrade is documented in:

```text
docs/DOWNLOAD_PORTAL_PLAN.md
```

Required upcoming portal features include:

- hamburger menu;
- release/version history;
- version detail pages;
- fixes/new features per version;
- known limitations;
- compatibility information;
- durable changelog record;
- current release integrity/download information;
- public release history generated from tracked source, not manually edited only on the VPS.

## Immediate next phase — physical beta.5 acceptance

Do this before declaring beta.5 accepted or bumping beta.6.

### Solo

- install/update beta.5 on physical Android;
- login;
- lobby visuals and character preview;
- start Campaign;
- verify loading/spawn;
- movement/cameras;
- sprint toggle;
- crouch/prone/jump;
- HP/ammo/weapon HUD;
- rifle/pistol/machete;
- reload/reserves;
- zombie kills/ammo drop/pickup;
- zombie animations;
- day/night/flashlight;
- Game Over/Restart;
- no crash/ANR.

### Duo

Prefer two phones on different Internet paths.

- both join one squad;
- leader starts;
- both receive same match/endpoint and different tickets;
- both spawn in same child instance;
- movement/combat/zombies/pickups replicate;
- deliberately disconnect one device;
- reconnect inside 42-second window;
- same player state/entity returns;
- complete or fail match;
- both see authoritative result;
- both return to refreshed/unlocked lobby.

### Three and four players

Repeat the same lifecycle with 3, then 4 devices/users if available. Test revive/downed/death, simultaneous combat, pickups and zombie load.

### Monitor VPS

Watch service/match logs during the test and confirm:

- child process creation;
- dynamic UDP port;
- READY;
- IN_MATCH;
- reconnect count;
- RESULT;
- child cleanup/reap;
- no stuck/frozen child after test.

## What to do after physical tests

Decision order:

1. If there is a blocker/crash/network failure, fix it first in source and rerun gates/deploy.
2. If beta.5 is usable, record compatibility findings.
3. Then improve the download portal as a contained web block.
4. After portal work, continue gameplay/product roadmap based on priority and physical feedback.

Do not bump beta.6 merely because documentation or portal code changes unless a new Android/server build is intentionally being cut.

## Major pending systems after current acceptance

- full main-menu settings page;
- HUD editor: drag/scale/opacity/visibility/reset;
- audio buses and real weapon/zombie/ambience/music/UI audio;
- player animation expansion/retargeting;
- zombie Hurt/Death animation assets;
- environment art/structures/vehicles/debris;
- map/detail expansion;
- physical performance optimization driven by measurements;
- latency/reconnect/abuse soak;
- wider Android compatibility matrix;
- additional missions/content/progression/loot/weapons/zombies;
- voice chat only after core co-op/performance are stable.

## Required reading order in a new chat

1. `docs/HANDOFF_BETA_5.md`
2. `docs/CURRENT_STATUS.md`
3. `docs/ROADMAP.md`
4. `docs/DOWNLOAD_PORTAL_PLAN.md`
5. `docs/beta/RELEASE_HISTORY.md`
6. Relevant subsystem docs only when touching that subsystem.

## Prompt to paste into a new chat

Copy the text below into a new conversation:

```text
Estamos continuando el proyecto NEXORA: DEADFALL.

Repositorio:
Gh0stDeveloper/NEXORA-DEADFALL

Rama activa:
agent/bootstrap-deadfall

PR:
#1, debe permanecer abierta y Draft. No hagas merge a menos que yo lo autorice explícitamente.

Usa el conector de GitHub y primero lee estos documentos directamente del repositorio actual:
1. docs/HANDOFF_BETA_5.md
2. docs/CURRENT_STATUS.md
3. docs/ROADMAP.md
4. docs/DOWNLOAD_PORTAL_PLAN.md
5. docs/beta/RELEASE_HISTORY.md

Después verifica el HEAD actual de la rama y el estado de la PR, porque puede haber commits de documentación posteriores al último runtime desplegado.

Último runtime que ya compiló, pasó el --force y fue publicado correctamente:
f402f1696c0438447d76236122a5d82101a94cc0
NEXORA: DEADFALL 0.9.0-beta.5 / versionCode 900005.

La APK Release fue verificada con firma v2, publicada como /var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk y la API social/match pasó localhost + HTTPS.

No empieces el proyecto desde cero y no repitas fases ya completadas. Continúa desde la siguiente tarea pendiente documentada.

Prioridad inmediata:
- aceptación física real de beta.5 en Android: Solo -> Duo con disconnect/reconnect -> 3 -> 4 jugadores;
- arreglar primero cualquier blocker encontrado;
- después mejorar web/download-site con menú hamburguesa, historial de versiones, detalles por versión, correcciones/novedades, compatibilidad y un registro durable de releases según docs/DOWNLOAD_PORTAL_PLAN.md.

Mantén autoridad de servidor, tickets privados, UDP dinámico 24600-24749, API 24562 sólo localhost detrás de HTTPS y keystore persistente. Las correcciones de VPS deben quedar también en source/automatización.

GitHub Actions puede seguir bloqueado antes de runner por billing/spending; no consideres un run rojo con steps=null como fallo de source. Usa los gates reales de la VPS como fuente de verdad mientras eso continúe.

Cuando hagas cambios, súbelos a agent/bootstrap-deadfall, mantén PR #1 Draft y dime qué cambiaste, qué gate sigue y el orden del plan posterior.
```

That prompt plus the repository documents is intended to be sufficient to continue without access to the old chat.
# NEXORA: DEADFALL

Android-first 3D zombie survival shooter built with **Godot 4.6.3**, with offline Campaign/Horde gameplay and server-authoritative online co-op for up to four players.

## Current status

Current Closed Beta:

```text
0.9.0-beta.5
versionCode 900005
protocol 2
content version 1
Android target API 36
```

Last confirmed full runtime deployment:

```text
f402f1696c0438447d76236122a5d82101a94cc0
```

Beta.5 completed its VPS `--force` deployment successfully:

- Android Release APK exported successfully;
- APK Signature Scheme v2 verified;
- one signer verified;
- stable APK published;
- localhost control/social/match API validated;
- HTTPS API validated.

The **next acceptance gate is physical Android testing**, not another automatic version bump: Solo -> Duo with deliberate disconnect/reconnect -> 3 players -> 4 players.

## Start here

For development or a new ChatGPT/Codex session, read these in order:

1. [Beta.5 handoff / new-chat prompt](docs/HANDOFF_BETA_5.md)
2. [Current operational status](docs/CURRENT_STATUS.md)
3. [Master roadmap](docs/ROADMAP.md)
4. [Download portal/version-history plan](docs/DOWNLOAD_PORTAL_PLAN.md)
5. [Closed Beta release history](docs/beta/RELEASE_HISTORY.md)
6. [Persistent architecture/project context](docs/PROJECT_CONTEXT.md)

Older handoff/Phase 11 planning files remain historical references and should not override the documents above.

## Implemented gameplay

- Android touch movement/look/action controls.
- Walk, sprint, jump, crouch and prone.
- First-person, rear third-person and front third-person cameras.
- Persistent sensitivity and flashlight/night readability foundation.
- HP/ammo/weapon HUD.
- Rifle, pistol and machete loadout.
- Finite magazines/reserves and reload.
- Server-authoritative movement, damage, hits, health and ammunition online.
- Walker, Runner, Crawler, Tank and Screamer zombies.
- Horde waves, scoring, spawn/population budgets and Game Over/Restart.
- Gore/dismemberment budgets and gameplay effects.
- Campaign vertical slice with Mission 01/02 and checkpoint recovery.
- Day/night cycle.

## Multiplayer/social

- 1-4 player Squad.
- Guest account/login and unique server-side username.
- Public player ID.
- Friends/direct messaging foundation.
- Solo/Duo/Squad lobby.
- Party codes, join/leave, leader kick/start and squad chat.
- Server-authoritative party/match state.
- One dedicated Godot child process per orchestrated party.
- Dynamic match UDP range `24600-24749`.
- One private 256-bit admission ticket per party member.
- Host/port knowledge without a valid ticket is insufficient for admission.
- MTU-safe FastLZ snapshot transport using 900-byte chunks.
- Prediction/reconciliation/interpolation.

### Beta.5 lifecycle

- ticket-scoped reconnect restores the same authoritative player entity/state;
- Android recovery window: 42 seconds / max 10 attempts;
- 2-second match child heartbeat;
- frozen-child watchdog;
- startup/empty/absolute runtime TTLs;
- terminal child reaping;
- monotonic `READY -> IN_MATCH` after first admission;
- authoritative `VICTORY`, `DEFEAT` and `ABORTED` results;
- result screen and return to refreshed/unlocked lobby;
- privacy-safe aggregate lifecycle metrics.

## Models/animation

3D runtime assets are vendored from private repository `Gh0stDeveloper/Objetos3D`, pinned to:

```text
28ea7a10a18fbe05a91fb3d920678991fff4afef
```

Canonical runtime mappings:

- `operator_01.glb`
- `operator_02.glb`
- `zombie_animated.glb`
- `zombie_static.glb`

Current animation facts:

- `operator_02` exposes only generic `mixamo_com`; it is a safe neutral fallback, not fake separate locomotion states.
- Quaternius zombie mappings: Idle/Walk/Run/Crawl/Attack are verified.
- separate player semantic animation set and zombie Hurt/Death clips remain future work.

## Android/VPS production baseline

- Ubuntu 24.04 x86_64 or ARM64.
- Godot 4.6.3 plus export templates.
- OpenJDK 17.
- Android API 35/36 tooling; current build automation uses Build Tools 36.1.0 baseline.
- Node.js 24.
- Nginx + Certbot.
- persistent root-owned Android signing identity.
- generated Android-template sanitizer for the known redundant Godot Manifest merger attributes.
- Next.js download portal.

Important ports:

```text
80/tcp              HTTP
443/tcp             HTTPS portal/API
24560/udp           base/legacy gameplay
24561/tcp           room directory when used
24562/tcp           localhost-only control/social/match API
24600-24749/udp     orchestrated dedicated matches
```

Never expose TCP 24562 directly to the Internet.

## Clean VPS installation

The repository is private. Authenticate GitHub CLI first, then clone/check out the development branch.

```bash
gh auth login --hostname github.com --git-protocol https
gh auth setup-git --hostname github.com
gh repo clone Gh0stDeveloper/NEXORA-DEADFALL
cd NEXORA-DEADFALL
git checkout agent/bootstrap-deadfall
```

Install:

```bash
sudo bash deploy/vps/install.sh \
  --domain beta.example.com \
  --email admin@example.com \
  --repo Gh0stDeveloper/NEXORA-DEADFALL \
  --branch agent/bootstrap-deadfall
```

The managed `deadfall` service user also needs repository access for later automatic updates.

Full installer documentation: [docs/VPS_INSTALLER.md](docs/VPS_INSTALLER.md).

## Signing identity

First installation creates persistent signing material under:

```text
/etc/nexora-deadfall/signing/
```

**Back it up securely.** Normal updates must never regenerate or replace this signing identity.

## Validation / update commands

Tests without changing the last successful deployment:

```bash
sudo /opt/nexora-deadfall/deploy/vps/update.sh --tests-only
```

Full rebuild/deploy:

```bash
sudo /opt/nexora-deadfall/deploy/vps/update.sh --force
```

Administration:

```bash
nexora-deadfall status
nexora-deadfall update
nexora-deadfall build-app
nexora-deadfall build-web
nexora-deadfall build-all
nexora-deadfall logs 200
nexora-deadfall auth
nexora-deadfall https
nexora-deadfall test-models
```

The message below is non-blocking on a VPS with no attached Android device:

```text
cannot connect to daemon at tcp:5037: Connection refused
```

## APK distribution

A successful application deployment publishes the stable current APK at:

```text
/downloads/NEXORA-DEADFALL-latest.apk
```

The Next.js portal currently reads `/var/www/nexora-deadfall/release.json` dynamically and shows version, size, SHA-256 and download action.

The planned portal upgrade adds a hamburger menu, durable version history, version-detail pages, fixes/features/known issues and compatibility information. See [docs/DOWNLOAD_PORTAL_PLAN.md](docs/DOWNLOAD_PORTAL_PLAN.md).

## Important managed paths

```text
/opt/nexora-deadfall                  Git checkout
/var/lib/nexora-deadfall             runtime/build/match state
/etc/nexora-deadfall                 config + signing secrets
/var/www/nexora-deadfall             APK/release metadata
/var/log/nexora-deadfall             logs
/usr/local/bin/nexora-deadfall       admin command
```

## Next development order

1. Physical beta.5 Solo acceptance.
2. Physical Duo over public Internet.
3. Deliberate disconnect/reconnect and same-state recovery.
4. Authoritative result -> both clients return to lobby.
5. Three-player test.
6. Four-player test.
7. Fix any blocker discovered by real devices.
8. Record compatibility/performance/thermal results.
9. If beta.5 is usable, implement the download portal/version-history upgrade.
10. Continue settings/HUD editor/audio, animation/art/content and deeper multiplayer soak according to the master roadmap.

Voice chat remains deferred until core co-op and Android performance are stable.
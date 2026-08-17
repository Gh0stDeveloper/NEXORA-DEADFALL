# NEXORA: DEADFALL — Quality Gates

Last updated: 2026-08-17.

A feature is not considered complete solely because its code exists. Apply the relevant automated, VPS, build and physical gates below.

## Gate 1 — Repository/import integrity

- Godot project imports headlessly on Godot 4.6.3.
- Main scene loads/instantiates.
- Required scripts/scenes/assets exist.
- No `Parse Error`, `Compile Error`, `SCRIPT ERROR` or dependency-load error.
- Shell scripts pass their syntax/contract tests.
- External model staging validates GLB files before import.

## Gate 2 — Strict gameplay compile

Primary gate:

```text
scripts/ci/gameplay_compile_smoke.gd
```

It covers the current gameplay/presentation script surface and launches feature/lifecycle child smokes.

Expected markers include:

```text
NEXORA: DEADFALL strict gameplay compile smoke passed
NEXORA: DEADFALL gameplay features smoke passed
NEXORA: DEADFALL lobby/mobile presentation smoke passed
NEXORA: DEADFALL beta.5 match lifecycle smoke passed
```

A success marker does not override earlier/later script errors in the same process output.

## Gate 3 — Core gameplay regressions

Relevant deterministic/scene smokes include:

- `smoke.gd` — project/scene/network-session contracts;
- `combat_smoke.gd` — weapon/damage/ammo/reload;
- `zombie_smoke.gd` — zombie state/authority/combat;
- `gore_smoke.gd` — effect budgets/dismemberment;
- `horde_smoke.gd` — wave/scoring/game-over/scaling;
- `network_smoke.gd` — network command/authority contracts;
- `squad_smoke.gd` — four-player/downed/revive/reconnect budgets;
- `campaign_smoke.gd` — Campaign/objective/checkpoint authority;
- `beta_hardening_smoke.gd` — release compatibility/privacy/hardening.

## Gate 4 — Phase 11.3 networking/matchmaking

Current specialized tests:

- `phase11_network_transport_smoke.gd` — MTU-safe/FastLZ snapshot and replicated gameplay fields;
- `phase11_external_models_smoke.gd` — external GLB import/runtime animation capability;
- `phase11_social_matchmaking_smoke.gd` — squad privacy/lock/leader rules;
- `phase11_orchestration_smoke.gd` — real Linux child-process orchestration/ticket admission;
- `phase11_smoke.gd` — parent Phase 11.3 gate.

The real orchestration smoke must use isolated validation UDP ports, not the production dynamic range.

## Gate 5 — Phase 12 / beta.5 lifecycle

Files:

- `phase12_match_lifecycle_smoke.gd`;
- `phase12_ticket_probe.gd`;
- real child orchestration invoked from the Phase 11.3 parent gate.

Required semantics:

- missing ticket rejected;
- valid ticket admitted;
- graceful ENet disconnect;
- same ticket reconnects to same authoritative entity;
- reconnect telemetry increments;
- second party member admitted;
- heartbeat reports monotonic first-admission state;
- parent promotes/keeps `IN_MATCH` even during temporary reconnect gaps;
- lifecycle health remains aggregate/private-safe;
- child process is cleaned up/reaped.

## Gate 6 — Android generated-template patch

File:

```text
scripts/ci/android_template_patch_smoke.sh
```

It verifies:

- the Android patch script compiles;
- exactly the intended redundant Manifest merger attributes are removed;
- unrelated `tools:replace` declarations are preserved;
- compileSdk 36 suppression is idempotent;
- Gradle hook contract remains present;
- the smoke does not dirty the repository.

## Gate 7 — VPS tests-only

Before a new runtime deployment:

```bash
sudo /opt/nexora-deadfall/deploy/vps/update.sh --tests-only
```

This must finish with:

```text
[DEADFALL] Gates de validación completados
```

and no blocking Godot/script/crash errors.

`--tests-only` must not overwrite the last-successful deployment state when a candidate fails.

## Gate 8 — Full production build/deploy

Only after tests-only passes for the intended runtime cut:

```bash
sudo /opt/nexora-deadfall/deploy/vps/update.sh --force
```

Required output/behavior:

- server/app/web/deploy validation succeeds;
- Android Release Gradle export succeeds;
- APK is signed with the persistent identity;
- `apksigner` verifies the intended scheme/signer;
- publication is atomic;
- current release metadata is written;
- services restart successfully;
- localhost API health passes;
- HTTPS API health passes;
- updater records successful commit only at the end.

## Gate 9 — Android package/signing

- ARM64 release installs on real Android hardware.
- Persistent release key is reused.
- Release identity/version matches `BuildInfo.gd` and export presets.
- No signing secrets are committed.
- Stable APK route is downloadable and SHA-256 matches published metadata.

## Gate 10 — Physical Solo acceptance

For each meaningful gameplay candidate:

- login/lobby;
- character preview;
- load/spawn;
- movement/cameras;
- mobile controls;
- HP/ammo/weapon HUD;
- rifle/pistol/machete;
- reload/reserves;
- zombie combat/drop/pickup;
- day/night/flashlight;
- Game Over/Restart;
- no crash/ANR.

## Gate 11 — Physical multiplayer acceptance

Current beta.5 sequence:

1. Duo public Internet.
2. Deliberately disconnect one client.
3. Reconnect inside 42 seconds.
4. Verify same identity/entity/state.
5. Verify authoritative result.
6. Verify connected squad returns to unlocked/refreshed lobby.
7. Repeat with 3 players.
8. Repeat with 4 players.
9. Validate DOWNED/revive/death, pickups and zombie load.
10. Prefer Wi-Fi and mobile-data paths.

Monitor the VPS for child start/READY/IN_MATCH/reconnect/RESULT/cleanup.

## Gate 12 — Physical performance/compatibility

Record actual measurements/observations in `docs/beta/COMPATIBILITY_MATRIX.md`.

Target coverage:

- lower-memory device;
- current mid-range;
- higher-end where available;
- Adreno and Mali where practical;
- FPS p50 / 1% low where measurable;
- peak RAM;
- thermal state after sustained gameplay;
- Smooth/Standard/Ultra comparison;
- background/foreground behavior.

A device is not compatible merely because the APK installs.

## Gate 13 — Download portal/version-history phase

When Phase 13 is implemented:

- Next.js production build passes;
- release-history schema validates;
- current version exists exactly once;
- version-list and detail routes render;
- invalid version returns clean not-found behavior;
- hamburger menu works on mobile;
- current APK URL remains correct;
- portal SHA-256 matches the public APK;
- web-only change does not rebuild Android unnecessarily;
- HTTPS endpoint remains healthy;
- real Android-browser viewport smoke passes.

See `docs/DOWNLOAD_PORTAL_PLAN.md`.

## GitHub Actions interpretation

GitHub Actions remains part of the intended CI system. However, a run rejected before runner execution because of billing/spending/account state and showing `steps=null` is not evidence that source tests failed.

Do not mark GitHub CI green until runner steps actually execute and pass. Use VPS gates as the source of truth while Actions cannot execute.

## Release discipline

- Docs-only changes do not require a beta bump or runtime deploy.
- Physical beta.5 blockers should be fixed before unrelated feature expansion.
- When a new runtime version is intentionally cut, update version identity/export/release notes/compatibility together.
- Run tests-only -> full force -> physical acceptance in that order.
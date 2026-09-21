# NEXORA: DEADFALL — Master Roadmap

Last updated: 2026-09-21.

Legend:

- [x] implemented/closed at source level;
- [~] implemented but still needs a stated physical/production acceptance gate;
- [ ] pending.

Current runtime deployment: `0.9.0-beta.5 / 900005` at `f402f1696c0438447d76236122a5d82101a94cc0`.

## City/simulation iteration — beta.6 (PR #16)

- [x] Recoverable phase checkpoints on `agent/city-simulation-upgrade`.
- [x] 192 × 192 m shared city with fifteen accessible interiors.
- [x] Natural surfaces, vegetation, wrecks and client-side fire.
- [x] Correct horde pursuit, navigation elevation, curbs and disconnected targets.
- [x] Dedicated simulation without presentation nodes; 60 Hz physics/frame cap.
- [x] Persistent lobby HTTP measurement separated from gameplay ENet RTT.
- [x] VALERIA and DANTE; stable account IDs and weapon grips.
- [x] Four-client loopback simulation measurement and automated city gates.
- [~] Signed beta.6 APK, physical Android performance and live VPS/WAN measurements.

Recovery and exact results: `docs/HANDOFF_CITY_SIMULATION.md`.

## Phase 0 — Foundation

- [x] Repository bootstrap.
- [x] Godot project foundation.
- [x] Shared local/network authority model.
- [x] Damage/health foundations.
- [x] Dedicated ENet server bootstrap.
- [x] CI/VPS deployment scaffolding.
- [x] Living GDD/architecture documentation.

## Phase 1 — Player vertical slice

- [x] CharacterBody3D controller.
- [x] Walk/sprint/jump/crouch/prone.
- [x] Touch joystick/look.
- [x] FPS/rear TPS/front TPS cameras.
- [x] Mobile HUD/safe area.
- [x] Android diagnostics/export workflow.
- [x] Persistent sensitivity foundation.
- [x] Flashlight/night-readability foundation.
- [~] Continue ergonomics validation on multiple real Android form factors.

## Phase 2 — Weapons and damage

- [x] Weapon data/runtime resources.
- [x] Rifle hitscan/cadence/ammo/reload.
- [x] Pistol.
- [x] Machete authoritative melee.
- [x] Weapon selector/loadout.
- [x] Body hitboxes/multipliers/critical hits.
- [x] Server-authoritative damage/ammo/hit result.
- [x] Replicated weapon action sequence presentation.
- [x] Combat smoke gates.
- [~] Physical feel/balance tuning remains ongoing.

## Phase 3 — Zombie vertical slice

- [x] Data-driven zombie base.
- [x] Walker.
- [x] Navigation/perception.
- [x] IDLE/SEARCH/CHASE/ATTACK/STAGGER/DEAD behavior foundation.
- [x] Authoritative melee.
- [x] Zombie smoke coverage.

## Phase 4 — Gore vertical slice

- [x] Prepared wound/detachment model.
- [x] Pooled limbs/corpse/blood/decal budgets.
- [x] Leg -> crawler behavior.
- [x] Arm penalties.
- [x] Head critical/death handling.
- [x] Quality-tier gore budgets.
- [~] Continue physical Android performance/thermal profiling.

## Phase 5 — Offline Horde

- [x] HordeDirector lifecycle.
- [x] Spawn safety/population budgets.
- [x] Wave progression/scoring.
- [x] Walker/Runner/Crawler/Tank/Screamer.
- [x] Game Over/Restart.
- [x] Horde HUD.
- [x] Multiplayer/downed-aware Game Over semantics.
- [~] Physical Horde stress/thermal acceptance remains part of beta testing.

## Phase 6 — Multiplayer Duo

- [x] NetworkAuthority rejects client-authoritative state.
- [x] Dedicated ENet room.
- [x] Sequenced/sanitized input commands.
- [x] Server-authoritative movement.
- [x] Prediction/reconciliation.
- [x] Remote player/zombie interpolation.
- [x] Authoritative weapons/damage/ammo/reload.
- [x] Room code/directory foundations.
- [x] Reconnect reservation foundation.
- [x] Headless two-peer integration tooling.
- [~] Real two-phone beta.5 acceptance is now the next primary physical gate.

## Phase 7 — Four-player Squad

- [x] Four-player capacity/spawn slots.
- [x] Protocol v2.
- [x] ALIVE -> DOWNED -> DEAD.
- [x] Bleedout.
- [x] Server-selected/range-validated revive.
- [x] DOWNED movement/weapon restriction.
- [x] Squad HUD.
- [x] Reconnect slot reservation/capacity accounting.
- [x] Four-player Horde scaling.
- [x] Per-quality snapshot/zombie/payload budgets.
- [x] Distance-based zombie relevance.
- [x] Squad and integration smokes.
- [~] Physical 3/4-player latency/revive/FPS soak pending.

## Phase 8 — Campaign vertical slice

- [x] OutbreakDistrict.
- [x] Data-driven missions/objectives.
- [x] REACH/KILL/SURVIVE/INTERACT/EXTRACT framework.
- [x] Mission 01 — First Signal.
- [x] Mission 02 — Last Broadcast.
- [x] Checkpoint persistence/recovery.
- [x] Dedicated campaign authority.
- [x] Campaign replication/HUD.
- [x] Day/night cycle.
- [x] Campaign smoke/integration harness.
- [~] Full physical campaign playthrough/performance validation remains ongoing.

## Phase 9 — Closed Beta hardening

- [x] Build/version/content/protocol compatibility.
- [x] Update-required rejection paths.
- [x] Network abuse/rate-limit/strike foundation.
- [x] Hardened PlayerCommand validation.
- [x] Runtime diagnostics/crash breadcrumb.
- [x] Android device/capability quality recommendation.
- [x] Hardened Campaign saves with integrity/backup recovery.
- [x] APK/AAB signing workflow foundations.
- [x] Release manifest/checksum.
- [x] Tester/release/legal/store preparation docs.
- [x] Compatibility matrix template.
- [~] Representative physical-device matrix remains incomplete.

## Phase 10 — VPS production and distribution

- [x] Ubuntu 24.04 x86_64/ARM64 installer/updater.
- [x] Godot 4.6.3/export templates.
- [x] JDK 17 and Android SDK/API 35/36 tooling.
- [x] Build Tools 36.1.0 current baseline.
- [x] Node.js/Nginx/Certbot/GitHub CLI.
- [x] Private repository auth/update flow.
- [x] Persistent Android release keystore generated once.
- [x] Root-only signing storage.
- [x] Signed Release APK build and apksigner verification.
- [x] Stable APK publication and release metadata.
- [x] Next.js download portal.
- [x] HTTPS/Nginx.
- [x] systemd game/download services.
- [x] Differential one-command updater.
- [x] Real production `--force` deployments completed through beta.5.
- [x] Android generated-template sanitizer for redundant Manifest merger directives.
- [x] Closed Beta release workflow derives version from `BuildInfo.gd`.
- [~] Continue clean-install regression testing when installer/toolchain changes.

## Phase 11.1 — Mobile polish/settings/lobby foundation

- [x] Persistent settings schema.
- [x] Touch sensitivity.
- [x] In-match sensitivity panel.
- [x] HUD overlap correction.
- [x] Circular icon-based mobile controls.
- [x] Flashlight.
- [x] Night readability pass.
- [x] HUD-layout persistence data model.
- [x] Guest identity/account foundation.
- [x] Initial lobby shell.
- [x] Character catalog.

Still pending from the original Phase 11 plan:

- [ ] Full main-menu settings screen.
- [ ] Visual HUD editor: drag/scale/opacity/visibility/reset.
- [ ] Production audio buses/controls.
- [ ] Complete weapon/zombie/ambience/music/UI audio content.

## Phase 11.2 — Guest/social layer

- [x] Login gate.
- [x] Persistent guest account.
- [x] Generated authentication secret.
- [x] Server-side username uniqueness.
- [x] Challenge/proof authentication foundation.
- [x] Server-generated public player ID.
- [x] Friends/direct messaging foundation.
- [x] Server-authoritative squad social object.

## Phase 11.3 — Matchmaking, authority, models and presentation

### Squad matchmaking

- [x] Solo/Duo/Squad selection.
- [x] Server-generated six-character squad code.
- [x] Join/leave.
- [x] Leader kick/start.
- [x] Squad chat.
- [x] Character/member/ping display.
- [x] Same squad -> same match_id/host/port/process.
- [x] Unique private ticket per member.
- [x] Party lock during matchmaking/match.

### Dedicated MatchOrchestrator

- [x] UDP allocation from production `24600-24749`.
- [x] Child Godot process per orchestrated party.
- [x] MatchAdmission config.
- [x] Readiness marker before assignment is treated as ready.
- [x] Ticket required for gameplay entity admission.
- [x] Validation port range isolated from production range in smoke tests.

### Transport/authority

- [x] MTU-safe FastLZ snapshot transport.
- [x] 900-byte unreliable chunks.
- [x] Server-authoritative movement/HP/ammo/damage/hits/zombies/progression.
- [x] Stale-input neutralization.
- [x] Prediction/reconciliation/interpolation.
- [x] Ping scoring/presentation.

### Loading and gameplay blockers

- [x] Lobby -> matchmaking -> dedicated -> loading -> spawn path.
- [x] Loading timeout/failure/reentry handling.
- [x] Game Over/Restart input hardening.
- [x] Mobile sprint toggle/haptics.
- [x] HP/ammo/weapon HUD.
- [x] Rifle/pistol/machete.
- [x] Limited ammo/reserves.
- [x] Ammo drops/pickups replicated authoritatively.
- [x] Loadout replication.

### Models/animation

- [x] Vendored `Objetos3D` submodule pinned.
- [x] Canonical operator/zombie staging.
- [x] GLB validation/import smoke.
- [x] Automatic visual scale/floor/center normalization.
- [x] Player/zombie/lobby shared animation driver.
- [x] `operator_02` generic `mixamo_com` fallback.
- [x] Quaternius Idle/Walk/Run/Crawl/Attack mappings.
- [ ] Add/retarget separate player Idle/Walk/Run/Attack/Hurt/Death clips.
- [ ] Add/verify Quaternius Hurt/Death clips.

### Presentation/performance

- [x] Lobby 2.0 atmosphere/operator stage/turntable.
- [x] Day/night.
- [x] Render scale by quality.
- [x] Mesh LOD by quality.
- [x] MSAA by quality.
- [x] FPS targets by quality.
- [x] Zombie visual-distance culling.
- [x] Headless presentation models disabled.
- [~] Tune values from physical-device measurements.

## Phase 12 — beta.5 dedicated-match lifecycle

Version: `0.9.0-beta.5 / 900005`.

### Reconnect/recovery

- [x] Ticket-scoped reconnect.
- [x] Same authoritative entity restored.
- [x] Slot/state preserved server-side.
- [x] Android reconnect window 42 seconds / 10 attempts.
- [x] Client never uploads trusted recovery state.
- [x] Real ENet disconnect/reconnect regression probe.

### Child lifecycle

- [x] Heartbeat every 2 seconds.
- [x] Parent stale-heartbeat watchdog.
- [x] Frozen-process detection/reap.
- [x] Startup timeout.
- [x] Empty-match timeout after a previously admitted player.
- [x] Absolute runtime TTL.
- [x] Terminal result reaping.
- [x] Monotonic first-admission state: READY -> IN_MATCH does not revert during reconnect gaps.

### Result/return flow

- [x] Server-authoritative VICTORY/DEFEAT/ABORTED.
- [x] Score/kills/wave/reason result payload.
- [x] Client result overlay.
- [x] Manual/automatic return to refreshed lobby.
- [x] Squad unlock/refresh.

### Lifecycle telemetry

- [x] Started/completed/defeated/aborted/failed/frozen/crashed/reaped/reconnect counters.
- [x] Safe aggregate `/v1/health` output.
- [x] No public ticket/guest/match/PID/path leakage from lifecycle health payload.

### Automated acceptance

- [x] `--tests-only` gates reached beta.5 lifecycle/real orchestration success before production cut.
- [x] Full production `--force` completed at `f402f169...`.
- [x] APK Release signed/published.
- [x] localhost + HTTPS API checks passed.
- [~] Physical beta.5 lifecycle acceptance remains the current blocker to calling this phase fully accepted.

## Phase 12-D — Immediate physical beta.5 acceptance

This is the current priority.

### Solo

- [ ] Install/update beta.5 on physical Android.
- [ ] Login/lobby/operator preview.
- [ ] Start/load/spawn Campaign.
- [ ] Validate movement/cameras/mobile actions.
- [ ] Validate rifle/pistol/machete and ammo UI.
- [ ] Validate ammo drops/pickups.
- [ ] Validate zombies/animations/gore.
- [ ] Validate day/night/flashlight.
- [ ] Validate Game Over/Restart.
- [ ] Record crashes/ANRs/performance issues.

### Duo public Internet

- [ ] Same squad, same match instance.
- [ ] Both spawn.
- [ ] Movement/combat/zombies/pickups replicate.
- [ ] Deliberately disconnect one client.
- [ ] Reconnect inside 42 seconds.
- [ ] Same identity/entity/state restored.
- [ ] Authoritative result delivered.
- [ ] Both return to unlocked/refreshed lobby.
- [ ] Test Wi-Fi and mobile data paths where practical.

### Three/four players

- [ ] 3-player run.
- [ ] 4-player run.
- [ ] DOWNED/revive/death.
- [ ] Multi-player ammo pickup contention.
- [ ] Zombie/Horde load.
- [ ] Process cleanup after result/disconnect.

### Performance matrix

- [ ] Lower-memory device.
- [ ] Mid-range device.
- [ ] High-end device where available.
- [ ] FPS/1% low observations.
- [ ] RAM/thermal observations.
- [ ] Smooth/Standard/Ultra comparison where practical.

## Phase 13 — Download portal / release history upgrade

The source implementation is now on `agent/bootstrap-deadfall`; production web and mobile-browser acceptance are still pending.

- [x] Durable structured release-history source.
- [x] Preserve/merge history during deployments.
- [x] Hamburger mobile menu.
- [x] Inicio/current release.
- [x] Version history page/timeline.
- [x] Version detail route.
- [x] Added/changed/fixed/known-issues sections.
- [x] Compatibility information.
- [x] Integrity/SHA-256 presentation.
- [x] Current/superseded/withdrawn states.
- [ ] Reconstruct exact beta.2/beta.3 notes from Git history before public detailed display.
- [x] Next.js production/build/schema gates.
- [ ] HTTPS/mobile-browser validation.

Detailed design: `docs/DOWNLOAD_PORTAL_PLAN.md`.

## Phase 14 — Settings, HUD customization and audio

- [x] Main-menu audio, sensitivity and quality settings UI.
- [~] Device listening/touch/performance validation of the new presentation.
- [x] Master/music/SFX/UI/ambience buses.
- [x] Persistent volume controls.
- [ ] HUD editor.
- [ ] Drag controls.
- [ ] Scale controls.
- [ ] Opacity.
- [ ] Visibility.
- [ ] Individual/all reset.
- [ ] Bounds/safe-area recovery.
- [x] Gunshot audio.
- [x] Zombie vocals.
- [x] Environment ambience.
- [x] Music.
- [x] UI feedback audio.

### Tactical presentation delivery — 2026-09-16

- [x] Visual threaded boot and verified-account loading/retry.
- [x] Original hangar art, amber/cyan theme, icons and licensed font.
- [x] Shared Solo/Duo/Squad 3D staging and integrated social/arsenal/operator panels.
- [x] Correct skinned-model normalization and fitted tactical equipment.
- [x] Procedural operator locomotion/poses and weapon-grip IK.
- [x] Detailed rifle/pistol/machete, first-person hands and firing feedback.
- [x] Zombie variants, verified locomotion/attack clips and persistent gore.
- [x] Original audio bank, music/ambience and bounded spatial mixing.
- [x] Sixteen local regression/integration gates and rendered account-to-combat flow.
- [~] Fresh Android export and physical acceptance of this source phase.

See `docs/HANDOFF_TACTICAL_PRESENTATION.md`. Source completion does not replace
physical acceptance or the remaining authored-animation/environment work below.

## Phase 15 — Art/animation/content pass

- [ ] Full player semantic animation set/retargeting.
- [ ] Zombie Hurt/Death animation coverage.
- [ ] Environment structures/houses/walls.
- [ ] Abandoned vehicles/debris.
- [ ] Fire/FX presentation.
- [ ] Map detail and navigation pass.
- [ ] Additional missions/objectives.
- [ ] Additional weapons/loot/progression.
- [ ] Additional zombie variants/encounters.

## Phase 16 — Multiplayer soak and wider beta

- [ ] Long-duration 4-player soak.
- [ ] Latency/jitter/loss scenarios.
- [ ] Reconnect abuse/edge cases.
- [ ] Invalid RPC/input fuzz expansion.
- [ ] Server memory/CPU monitoring under concurrent matches.
- [ ] Dynamic-port exhaustion/capacity behavior.
- [ ] Frozen child watchdog fault-injection test.
- [ ] Wider tester compatibility matrix.
- [ ] Crash/ANR aggregation process.

## Future — Squad voice chat

Architecture has been researched/documented but remains intentionally deferred.

- [ ] Runtime microphone permission/capture.
- [ ] Native Opus bridge.
- [ ] Unreliable voice relay.
- [ ] Jitter buffer/playback.
- [ ] Echo/noise/device handling.
- [ ] Mute/block/PTT/open-mic UX.
- [ ] Abuse/moderation controls.

Do not prioritize voice chat ahead of stable core co-op, physical performance and lifecycle reliability.

## Release/version policy

- Do not bump a beta version just for docs-only changes.
- Fix physical beta.5 blockers on beta.5 unless compatibility/wire/runtime changes require a new cut.
- When cutting a new Android/server beta, update `BuildInfo.gd`, export presets, compatibility docs and release notes together.
- Run `--tests-only` first, then full `--force`, then physical acceptance.
- GitHub Actions red runs with `steps=null` due billing/spending are not source-test failures.

## Working order from here

1. Physical beta.5 Solo.
2. Physical beta.5 Duo + deliberate reconnect + result/lobby.
3. 3-player.
4. 4-player.
5. Fix any blocker first.
6. Record compatibility/performance.
7. Validate the Phase 13 portal/history implementation over HTTPS/mobile.
8. Continue Phase 14/15 according to physical feedback.
# Roadmap

## Phase 0 — Foundation
- [x] Repository initialization.
- [x] Godot project bootstrap.
- [x] Shared authority boundary.
- [x] Initial damage event model.
- [x] Dedicated ENet server bootstrap.
- [x] CI/server deployment scaffolding.
- [x] Living GDD and technical docs.
- [x] Bootstrap CI validated on Ubuntu/Godot/Android.

## Phase 1 — Player vertical slice
- [x] CharacterBody3D controller.
- [x] Walk/run/jump/crouch/prone.
- [x] Touch joystick and look region.
- [x] FPS/rear TPS/front TPS cameras.
- [x] Mobile HUD safe areas and desktop controls.
- [x] Android diagnostics/emulator workflow and ARM64 test APK pipeline.
- [ ] Validate controls/HUD ergonomics on a physical Android phone.

## Phase 2 — Weapons and damage
- [x] Weapon resources and NXR-4 hitscan rifle.
- [x] Cadence, ammunition, timed reload and ShotIntent.
- [x] Seven body hitboxes, HealthComponent and authority registry.
- [x] Damage resolver/body multipliers/critical hits.
- [x] Combat smoke coverage.
- [ ] Re-run gates after Actions billing/spending is unblocked.

## Phase 3 — First zombie
- [x] Data-driven ZombieBase/Walker.
- [x] Navigation, perception and IDLE/SEARCH/CHASE/ATTACK/STAGGER/DEAD.
- [x] Authoritative melee and dedicated simulation authority.
- [x] Zombie combat smoke tests.
- [ ] Re-run gates after Actions billing/spending is unblocked.

## Phase 4 — Gore vertical slice
- [x] Prepared detachable rig/wounds and thresholds.
- [x] Pooled limbs/corpse/blood/decals and quality budgets.
- [x] Leg→crawler, arm penalties, head critical death.
- [x] Gore tests and Android telemetry.
- [ ] Physical Android profiling.
- [ ] Re-run gates after Actions billing/spending is unblocked.

## Phase 5 — Offline horde
- [x] HordeDirector lifecycle and quality population budgets.
- [x] Safe spawn points, wave progression and scoring.
- [x] Walker, Runner, Crawler, Tank and Screamer.
- [x] GAME_OVER/restart, Horde HUD, smoke tests and Android telemetry.
- [ ] Physical Android Horde/FPS profiling.
- [ ] Re-run gates after Actions billing/spending is unblocked.

## Phase 6 — Multiplayer duo
- [x] NetworkAuthority that rejects client-side authoritative damage.
- [x] Dedicated two-peer ENet room and dynamic network player entities.
- [x] Sequenced input command replication with server sanitation.
- [x] Server-authoritative CharacterBody3D movement simulation.
- [x] Local prediction and authoritative reconciliation.
- [x] Remote-player and zombie snapshot interpolation.
- [x] Server-authoritative fire cadence/ammo/reload/hitscan/damage.
- [x] Player/weapon/zombie/Horde snapshots.
- [x] HordeDirector generalized for multiplayer/server ownership.
- [x] Six-character room code plus lightweight directory service contract.
- [x] Resume token/reconnect groundwork.
- [x] Network authority/command/room smoke tests.
- [x] Real headless two-client ENet integration harness committed to CI.
- [x] Android network diagnostics hooks.
- [ ] Execute two-peer CI/Docker/Android validation after Actions billing/spending is unblocked.
- [ ] Physical two-phone Android soak/profile test.

## Phase 7 — Four-player squad
- [x] Four-player ENet capacity and four stable player spawn slots.
- [x] Protocol v2 room/session contract and directory `max_players=4` metadata.
- [x] ALIVE → DOWNED → DEAD authoritative player life state.
- [x] 30-second bleedout and authoritative final death.
- [x] Server-selected, range-validated, three-second revive hold.
- [x] DOWNED movement restriction and weapon/reload lock.
- [x] Squad HUD with HP/downed/bleedout/revive/dead presentation.
- [x] Android REVIVE/INTERACT control and Squad telemetry.
- [x] 45-second reconnect reservations that preserve entity ID and player slot.
- [x] Reserved reconnect slots count against four-player room capacity.
- [x] Rejected peers release their client ENet connection.
- [x] Four-player Horde wave and population scaling.
- [x] Recoverable-player-aware Horde GAME_OVER and spawn safety.
- [x] Per-quality snapshot frequency, zombie-detail and payload budgets.
- [x] Per-client zombie relevance prioritization by distance.
- [x] `network_smoke.gd` upgraded for Squad protocol/capacity.
- [x] `squad_smoke.gd` for downed/revive/bleedout/Horde/weapon/reconnect/budget restrictions.
- [x] Two-peer regression integration remains in CI.
- [x] Real four-client ENet Squad integration harness committed to CI.
- [x] Phase 7 technical documentation.
- [ ] Execute Phase 7 Godot/network/Docker/Android gates after Actions billing/spending is unblocked.
- [ ] Physical four-phone Android soak, revive, latency/reconciliation and FPS profiling.

## Phase 8 — Campaign vertical slice
- [x] `OutbreakDistrict` first production-style environment shell.
- [x] Data-driven campaign/mission/objective resources.
- [x] Shared sequential REACH/KILL/SURVIVE/INTERACT/EXTRACT objective framework.
- [x] Mission 01 — First Signal.
- [x] Mission 02 — Last Broadcast.
- [x] Local checkpoint persistence with schema/version guard and checkpoint spawn restore.
- [x] Dedicated-server campaign authority; network clients are presentation replicas only.
- [x] Separate lightweight campaign replication channel for 1–4 player sessions.
- [x] Campaign HUD and Android campaign diagnostics.
- [x] Campaign smoke test and four-peer Campaign integration harness committed to CI.
- [x] Voice-chat architecture investigation documented; implementation intentionally deferred.
- [ ] Execute Phase 8 Godot/Campaign/Docker/Android gates after Actions billing/spending is unblocked.
- [ ] Physical Android campaign playthrough and four-phone Campaign soak/profile test.

## Future multiplayer enhancement — Squad voice chat
- [x] Global squad voice architecture researched and documented.
- [ ] Microphone capture/runtime permission integration.
- [ ] Native Opus codec bridge.
- [ ] Dedicated unreliable voice transport/relay.
- [ ] Jitter buffer and generated-audio playback.
- [ ] Echo cancellation/noise suppression/device routing.
- [ ] Mute/block/push-to-talk/open-mic UX and abuse controls.

## Phase 9 — Closed beta hardening
- [x] Closed-beta build identity, content version and client/server compatibility handshake.
- [x] Room-directory build metadata and update-required rejection path.
- [x] Network abuse guard with payload validation, action rate limits, strikes and disconnect escalation.
- [x] Hardened `PlayerCommand` Variant/type/sequence validation.
- [x] Privacy-safe local runtime diagnostics and previous-unclean-session crash breadcrumb report.
- [x] Android device/GPU/memory capability snapshot and non-destructive quality recommendation.
- [x] Campaign save v2 with SHA-256 integrity, temporary write, backup recovery and v1 migration.
- [x] Persistent-signing Android AAB/APK Closed Beta release workflow using GitHub Secrets.
- [x] Release checksum and machine-readable build manifest generation.
- [x] Closed-beta tester guide, release checklist and physical-device compatibility matrix template.
- [x] Privacy notice, beta terms and code of conduct.
- [x] Store listing, Data Safety preparation and content-rating questionnaire notes.
- [x] ADB diagnostic bundle collection helper.
- [x] Closed Beta hardening smoke test integrated with all prior regression gates.
- [ ] Execute Phase 9 current-head CI/release gates after Actions billing/spending is unblocked.
- [ ] Complete representative physical-device compatibility matrix and closed-beta soak.

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
- [x] First-person camera.
- [x] Rear third-person camera.
- [x] Front third-person camera.
- [x] Mobile HUD safe areas.
- [x] Desktop keyboard/mouse debug controls.
- [x] Dedicated movement/camera test range.
- [x] Android runtime diagnostics and emulator validation workflow.
- [x] Installable ARM64 Phase 1.1 test APK workflow.
- [ ] Validate controls and HUD ergonomics on at least one physical Android phone.

## Phase 2 — Weapons and damage

- [x] Weapon data resources.
- [x] First NXR-4 hitscan rifle.
- [x] Fire cadence, ammunition and timed reload.
- [x] Shot-intent boundary for future network authority.
- [x] Seven body-part hitboxes.
- [x] Health component and authority registry.
- [x] Damage resolver, body multipliers and critical hits.
- [x] Desktop FIRE/RELOAD and Android FIRE/RELOAD input.
- [x] Combat smoke tests for normal/head/limb damage, cadence, ammo and reload.
- [ ] Re-run Phase 2 CI/Android gates after GitHub Actions billing/spending is unblocked.

## Phase 3 — First zombie

- [x] Data-driven ZombieBase and first Walker configuration.
- [x] NavigationAgent3D pathing with safe fallback.
- [x] Player detection, line of sight and last-known-position search.
- [x] Idle/search/chase/attack/stagger/dead state machine.
- [x] Authoritative melee DamageEvent attacks.
- [x] Seven zombie body hitboxes and HealthComponent integration.
- [x] Dedicated-server simulation authority boundary.
- [x] Death shutdown and pooled corpse handoff.
- [x] Headless zombie combat smoke tests committed to CI.
- [ ] Re-run Phase 3 Godot/Docker/Android gates after GitHub Actions billing/spending is unblocked.

## Phase 4 — Gore vertical slice

- [x] Prepared detachable limb rig contract; no runtime mesh cutting.
- [x] Per-body-part accumulated damage thresholds.
- [x] Limb mesh hide + wound/stump mesh reveal.
- [x] Pooled RigidBody3D detached limbs/corpse proxy.
- [x] Pooled GPUParticles3D blood bursts.
- [x] Budgeted pooled blood decals.
- [x] Smooth/Standard/Ultra/Ultra HD gore budgets.
- [x] Leg loss → crawler locomotion and reduced collision profile.
- [x] One/two-arm loss → reduced melee capability.
- [x] Head destruction → critical authoritative death.
- [x] Gore smoke tests and Android runtime statistics hooks.
- [x] Phase 4 technical documentation.
- [ ] Record representative physical-Android profiling after Actions/device validation is available.
- [ ] Re-run Phase 4 Godot/Docker/Android gates after GitHub Actions billing/spending is unblocked.

## Phase 5 — Offline horde

- [x] Authority-gated HordeDirector state machine.
- [x] Initial countdown, spawning, active wave and intermission lifecycle.
- [x] Quality-tier population-cost budgets and spawn-rate scaling.
- [x] Player-distance-aware spawn-point selection.
- [x] Progressive wave growth and completion bonuses.
- [x] Walker archetype.
- [x] Runner archetype.
- [x] Native Crawler archetype.
- [x] Tank archetype.
- [x] Screamer archetype with temporary nearby-zombie rage buff.
- [x] Per-archetype population cost, score value, unlock wave and spawn weight.
- [x] Score, kills, enemies remaining and wave counters.
- [x] Player death → GAME_OVER.
- [x] Restart/reset flow.
- [x] Safe-area-aware Horde HUD.
- [x] Headless deterministic Horde smoke tests committed to CI.
- [x] Android Horde runtime telemetry hooks.
- [x] Phase 5 technical documentation.
- [ ] Record physical-Android Horde population/FPS profiling across quality tiers.
- [ ] Re-run Phase 5 Godot/Docker/Android gates after GitHub Actions billing/spending is unblocked.

## Phase 6 — Multiplayer duo

- [ ] NetworkAuthority.
- [ ] Input replication.
- [ ] Prediction/interpolation/reconciliation.
- [ ] Server-authoritative shots and damage.
- [ ] Room code service.
- [ ] Two-player soak test.

## Phase 7 — Four-player squad

- [ ] Four-player replication budget.
- [ ] Downed/revive.
- [ ] Reconnect grace period.
- [ ] Four-player horde balance.

## Phase 8 — Campaign vertical slice

- [ ] First environment.
- [ ] Objective framework.
- [ ] 1–2 complete missions.
- [ ] Checkpoint/persistence design.

## Phase 9 — Closed beta

- [ ] Real-device compatibility matrix.
- [ ] Crash reporting.
- [ ] Abuse/cheat validation.
- [ ] Privacy/terms/code of conduct.
- [ ] Signed Android release pipeline.
- [ ] Store-ready metadata and rating questionnaire.

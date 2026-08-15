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

### Phase 1.1 — Android validation

- [x] Separate x86_64 Android emulator export preset for runtime CI.
- [x] Android runtime diagnostics for orientation, safe area, cutouts and DPI.
- [x] Emulator install/start/process-liveness gate.
- [x] Android-injected RUN/JUMP/CROUCH/PRONE/CAM touch validation.
- [x] Android-injected joystick and touch-look validation.
- [x] Logcat scan for GDScript/runtime errors, fatal exceptions and ANRs.
- [ ] Validate ergonomics and safe-area placement on at least one physical Android phone.

## Phase 2 — Weapons and damage

- [ ] Weapon data resources.
- [ ] First rifle.
- [ ] Fire/reload/ammo.
- [ ] Body-part hitboxes.
- [ ] Health component.
- [ ] Damage resolver and critical hits.

## Phase 3 — First zombie

- [ ] Navigation and target detection.
- [ ] Idle/search/chase/attack/dead states.
- [ ] Stagger.
- [ ] Basic attack damage.
- [ ] Death/ragdoll.

## Phase 4 — Gore vertical slice

- [ ] Detachable limb rig.
- [ ] Wound mesh swap.
- [ ] Pooled limb rigid bodies.
- [ ] Blood particles.
- [ ] Budgeted decals.
- [ ] Leg loss → crawler transition.

## Phase 5 — Offline horde

- [ ] Spawn director.
- [ ] Round progression.
- [ ] Multiple zombie archetypes.
- [ ] Score and end state.
- [ ] Performance profiling across tiers.

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

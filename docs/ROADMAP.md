# Roadmap

## Phase 0 — Foundation

- [x] Repository initialization.
- [x] Godot project bootstrap.
- [x] Shared authority boundary.
- [x] Initial damage event model.
- [x] Dedicated ENet server bootstrap.
- [x] CI/server deployment scaffolding.
- [x] Living GDD and technical docs.
- [ ] Confirm CI green on bootstrap PR.

## Phase 1 — Player vertical slice

- [ ] CharacterBody3D controller.
- [ ] Walk/run/jump/crouch/prone.
- [ ] Touch joystick and look region.
- [ ] First-person camera.
- [ ] Rear third-person camera.
- [ ] Front third-person camera.
- [ ] Mobile HUD safe areas.

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

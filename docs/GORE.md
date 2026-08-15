# Gore Vertical Slice

## Goals

Phase 4 connects authoritative body-part damage to prepared visual pieces and gameplay consequences without runtime mesh cutting or unbounded effect allocation.

## Prepared rig contract

Every gore-capable zombie exposes independent prepared meshes under `VisualRoot/PreparedRig` for `Head`, `LeftArm`, `RightArm`, `LeftLeg`, and `RightLeg`. Matching stump/wound meshes exist under `VisualRoot/Wounds` and start hidden.

When a limb crosses its accumulated resolved-damage threshold:

1. the prepared limb mesh is hidden;
2. the matching wound mesh is revealed;
3. the body-part `Area3D` hitbox is disabled;
4. a detached rigid-body proxy is acquired from the gore pool;
5. a pooled blood burst is restarted;
6. a budgeted pooled blood decal is placed;
7. gameplay consequences are emitted.

No runtime mesh slicing is used.

## Default Walker thresholds

| Body part | Accumulated resolved damage |
| --- | ---: |
| Head | 42 |
| Arm | 36 |
| Leg | 38 |

Damage accumulation uses `DamageEvent.resolved_amount`, so the Phase 2 body-zone multipliers remain authoritative.

## Gameplay consequences

- Destroyed head: emits a critical lethal follow-up through the active authority. The Gore component never writes health directly.
- One destroyed arm: melee damage multiplier 0.72 and cooldown multiplier 1.25.
- Two destroyed arms: melee damage multiplier 0.45 and cooldown multiplier 1.65.
- Destroyed leg: switches the zombie to crawler locomotion, lowers the collision profile, reduces movement speed to 42%, and reduces effective attack range.

## Runtime pools

`GoreManager` owns reusable pools for detached `RigidBody3D` pieces, `GPUParticles3D` blood bursts, and `Decal` blood marks. Ring cursors recycle slots when a budget is exhausted instead of creating new nodes per hit.

The manager may retain previously allocated slots if the user lowers quality after running a higher tier, but acquisition is always restricted to the current tier limit. This keeps runtime node count bounded by the highest configured profile reached during the session.

## Quality budgets

NEXORA: DEADFALL targets Godot's Mobile renderer on Android. Concurrent decal counts stay at or below eight, while higher tiers scale detached parts, blood emitters, particle density, and effect lifetimes.

| Tier | Detached parts | Blood emitters | Particles/burst | Decals | Limb lifetime | Decal lifetime |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Smooth | 4 | 2 | 10 | 4 | 5 s | 12 s |
| Standard | 8 | 4 | 18 | 6 | 8 s | 20 s |
| Ultra | 16 | 6 | 28 | 8 | 12 s | 35 s |
| Ultra HD | 32 | 8 | 40 | 8 | 16 s | 50 s |

Smooth remains mechanically uncensored: dismemberment and crawler/arm/head consequences still occur; only visual effect concurrency and lifetime are reduced.

## Android profiling hooks

Android debug builds include the current gore budget inside `DEADFALL_ANDROID_READY` and emit a `DEADFALL_GORE_STATS` JSON marker after startup. Runtime stats include request counts, pool sizes, active parts/decals, and peak active counts. These markers are intended for physical-device profiling and emulator log collection.

## Test coverage

`scripts/ci/gore_smoke.gd` validates:

- every quality tier has bounded positive pool limits;
- mobile profiles never exceed eight concurrent decals;
- ring allocation never returns a slot outside the configured limit;
- the prepared rig/wound contract exists;
- arm destruction swaps visual state and disables its hitbox;
- one/two-arm loss changes melee capability;
- leg destruction activates crawler locomotion and a reduced collider;
- head destruction forces death through authority.

## Remaining production work

This vertical slice uses primitive meshes and a pooled rigid proxy. Phase 4 is mechanically complete, but production art still requires final skinned character pieces, anatomical wound meshes, authored blood textures/materials, audio, and physical-device profiling across the target Android matrix.

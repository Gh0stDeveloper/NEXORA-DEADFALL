# Zombie AI — Phase 3

## Goal

Phase 3 introduces the first combat-capable zombie while preserving the shared offline/server authority model.

## Runtime composition

`Zombie.tscn` contains:

- `CharacterBody3D` movement body.
- `NavigationAgent3D` path helper.
- `HealthComponent` registered by entity ID.
- Seven Area3D body hitboxes shared with the damage pipeline.
- A data-driven `ZombieData` resource.
- A debug-only state label.

## State machine

`IDLE -> CHASE -> ATTACK`

The controller can also enter `SEARCH` after losing line of sight, `STAGGER` after non-lethal authoritative damage, and `DEAD` when health reaches zero.

State transitions emit `state_changed` and print debug markers in debug builds.

## Perception

The first Walker scans the `deadfall_player` group, selects the nearest living visible player in detection range, remembers the last known position, and searches for a short period after losing line of sight.

## Navigation

The test range uses a small runtime-baked NavigationMesh sourced from static colliders on physics layer 1. `NavigationAgent3D.get_next_path_position()` drives movement when a path exists. If navigation has not synchronized or a route is unavailable, the zombie falls back to direct collision-aware CharacterBody3D movement instead of freezing the state machine.

Production maps should use prebaked navigation data rather than runtime baking.

## Combat authority

Zombie melee attacks create `DamageEvent` objects and submit them to the active authority. The zombie never subtracts player health directly.

Local sessions use `LocalAuthority`. Dedicated servers use `DedicatedAuthority`, which currently shares the same authoritative health registry and damage rules while networking validation is built in later multiplayer phases. `NETWORK_CLIENT` mode does not run zombie AI as simulation authority.

## Damage reactions

Non-lethal hits transition the zombie to `STAGGER`. Lethal hits transition to `DEAD`, disable movement/attacks/navigation/collision hitboxes, and create a provisional RigidBody3D corpse proxy in visual builds.

The physics corpse is intentionally temporary. Phase 4 replaces it with the gore-aware limb/rig system and eventual skeletal ragdoll assets.

## Tests

`scripts/ci/zombie_smoke.gd` validates:

- scene composition and NavigationAgent3D presence;
- authoritative zombie melee damage to the player;
- authoritative rifle damage to zombie health;
- STAGGER on non-lethal damage;
- DEAD on lethal headshot;
- navigation deactivation on death;
- non-authoritative AI gating when no simulation authority is available.

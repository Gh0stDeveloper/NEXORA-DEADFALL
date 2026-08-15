# Combat architecture

## Phase 2 contract

NEXORA: DEADFALL combat is split into four boundaries:

1. **Input / weapon state** decides whether a shot may be emitted based on cadence, magazine, reserve ammunition and reload state.
2. **Shot intent** captures attacker, weapon, origin, direction, distance and simulation tick without mutating a target.
3. **Hit resolution** identifies the impacted body zone. In the current local vertical slice this is a Godot physics ray query; a network client must not authoritatively resolve damage.
4. **Authority** validates the `DamageEvent`, calculates body/damage-type modifiers, finds the registered `HealthComponent`, applies final damage and emits the result.

A weapon must never directly subtract target health.

## First rifle

`NXR-4 Carbine` is the Phase 2 test firearm:

- 28 base bullet damage
- 30-round magazine
- 120 reserve rounds
- 600 RPM
- 2.1 second reload
- 160 m hitscan range
- automatic fire

These are prototype values and are deliberately data-driven in `src/weapons/data/nxr_rifle_01.tres`.

## Body zones

The initial multipliers are:

| Zone | Multiplier |
| --- | ---: |
| Head | 2.25x |
| Chest | 1.00x |
| Abdomen | 0.90x |
| Arms | 0.65x |
| Legs | 0.70x |

Bullet and melee head impacts are marked critical. Fire currently applies an additional `0.65x` damage-type modifier. Balance values will move as enemy archetypes and armor are introduced.

## Authority registry

`LocalAuthority` owns an entity-id → health-component registry. `HealthComponent` registers itself when a local session is active. The registry stores instance IDs instead of owning Node references, and stale entries are rejected.

For online play, the client will send shot/input intent. `NetworkAuthority` and the dedicated server will validate weapon state and perform authoritative hitscan/damage resolution. Client-side hit feedback may be predicted, but authoritative health will never be accepted from the client.

## Test range

`TestTarget.tscn` exposes seven independent `Area3D` hitboxes for head, chest, abdomen, both arms and both legs. The target has entity ID `1001`, 100 HP, and a debug health label in non-headless builds.

## Input

Desktop prototype controls:

- Left mouse: fire
- R: reload

Android adds dedicated FIRE and RELOAD controls to the existing safe-area-aware HUD.

## Automated checks

`scripts/ci/combat_smoke.gd` verifies:

- authority registration and unknown-victim rejection
- chest bullet damage
- headshot critical damage
- combined body-zone and damage-type modifiers
- body-zone preservation through `DamageEvent`
- fire cadence enforcement
- empty-magazine enforcement
- timed reload behavior and ammo transfer

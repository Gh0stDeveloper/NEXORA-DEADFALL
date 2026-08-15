# Architecture

## Core rule

NEXORA: DEADFALL uses a shared gameplay simulation with pluggable authority.

```text
Gameplay input
    |
    v
GameAuthority
  |       |
  |       +--> NetworkAuthority --> Dedicated server
  +----------> LocalAuthority
    |
    v
Shared simulation systems
```

Online/offline differences belong at transport and authority boundaries, not inside weapons, zombie AI, damage rules or wave logic.

## Major layers

### Presentation

Android HUD, camera rigs, animation, audio, particles, decals and client interpolation. Presentation may predict or interpolate but cannot decide authoritative online outcomes.

### Simulation

Weapons, damage, health, zombie state, movement intent, waves, objectives, scoring, pickups and match rules. Simulation code should accept deterministic-enough inputs and explicit state rather than reading UI directly.

### Authority

`GameAuthority` is the boundary for operations whose validity matters. `LocalAuthority` resolves locally. A future `NetworkAuthority` will serialize client intent and await/reconcile server decisions.

### Transport

ENet/UDP through Godot MultiplayerAPI is the initial online transport. Transport code must not contain game balance rules.

### Persistence

Persistent profiles, unlocks and settings will be isolated from match simulation. Server-side identity/progression storage is a later milestone.

## Initial source layout

```text
src/autoload
src/core/authority
src/core/damage
src/main
src/server
```

Future modules are added only when they receive working code: `player`, `weapons`, `enemies`, `gore`, `modes`, `networking`, `ui`, `mobile`, `audio`, `persistence` and `maps`.

## Object pooling requirement

High-frequency transient objects must use pools when practical: blood particles, decals, casings, projectiles, detached limbs and high-volume enemy instances. Repeated instantiate/free loops are treated as a mobile performance risk.

## Architectural decision records

Major irreversible choices such as networking topology, persistence provider, tick rate and asset streaming should receive an ADR under `docs/adr/` before implementation.

# ADR 0001 — Shared gameplay simulation with authority adapters

**Status:** Accepted  
**Date:** 2026-08-15

## Context

The game must support offline solo/bots and online dedicated-server co-op without maintaining two implementations of damage, AI, waves, objectives and other match rules.

## Decision

Gameplay systems target a `GameAuthority` boundary. Offline sessions use `LocalAuthority`; online sessions will use `NetworkAuthority`, with final decisions performed by the dedicated server.

## Consequences

- Gameplay logic remains reusable across connectivity modes.
- Networking code cannot become the home of balance/gameplay rules.
- Core events need serializable, explicit data structures.
- Online prediction may temporarily diverge visually but must reconcile to authoritative state.

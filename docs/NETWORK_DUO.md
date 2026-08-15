# Multiplayer Duo — Phase 6 baseline

Phase 6 introduced the first two-player authoritative network slice. Phase 7 keeps that behavior as a regression mode while the same transport/session now supports up to four players. For the current protocol and capacity rules, see `docs/NETWORK_SQUAD.md`.

## Authority model

The dedicated server owns movement validation, firearm cadence/ammunition/reload, hitscan, damage, zombie AI and Horde progression. Network clients own input collection, local presentation and prediction only. `NetworkAuthority.resolve_damage()` rejects client-side authoritative damage.

## Transport retained from Phase 6

- ENet gameplay UDP: default `24560`.
- Room directory TCP/HTTP: default `24561`.
- Input commands: unreliable ordered channel 0.
- Server snapshots: unreliable ordered channel 1.
- Join, fire, reload and restart requests: reliable delivery.

A fire request contains only a monotonically increasing request sequence and client tick. It does not contain trusted damage, victim ID, hit result or ammo state. The server weapon builds the authoritative shot from the server-side player/camera transform and applies its own `WeaponRuntimeState` cadence/ammo/reload gates.

## Duo regression

`duo_integration.sh` still boots one headless server plus two ENet clients and requires both clients to observe `DEADFALL_DUO_SNAPSHOT players=2`. This ensures the four-player Phase 7 expansion does not regress the original Duo slice.

## Phase 7 changes

The live session now uses protocol v2, supports four player slots, 45-second slot-preserving reconnect reservations, ALIVE/DOWNED/DEAD life states, server-held revive, Squad-aware Horde scaling and per-client zombie replication budgets. The newer details are documented in `NETWORK_SQUAD.md`.

Current GitHub Actions execution remains dependent on the account billing/spending block being cleared.

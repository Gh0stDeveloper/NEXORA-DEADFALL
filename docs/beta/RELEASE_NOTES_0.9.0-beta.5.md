# NEXORA: DEADFALL 0.9.0-beta.5

Closed-beta lifecycle and recovery candidate.

## Included

- Ticket-scoped reconnect for orchestrated dedicated matches. A reconnect can only restore the authoritative entity/state associated with the same private match ticket and guest identity.
- Bounded Android reconnect flow: up to 42 seconds and 10 attempts, with dedicated loading/recovery presentation.
- Authoritative restoration of player entity, slot, transform/gameplay snapshot, health/life state and weapon/loadout state; clients do not upload trusted recovery state.
- Dedicated match heartbeat IPC every 2 seconds.
- Parent watchdog for stale heartbeat/frozen child processes.
- Startup, empty-session and absolute match TTLs plus terminal-process reaping.
- Server-authoritative `VICTORY`, `DEFEAT` and `ABORTED` results with score, kills, wave and reason.
- Result delivery to connected clients and automatic/manual return to a refreshed squad lobby.
- Aggregate lifecycle counters through `/v1/health` without exposing match IDs, tickets, guest identities, PIDs or private file paths.
- Real child-process regression probe that joins, closes ENet cleanly and reconnects using the same private ticket.

## Carried forward from beta.4

- Lobby 2.0 presentation and normalized animated GLB previews.
- Authoritative rifle/pistol/machete loadout and replicated ammo pickups.
- Mobile HP/ammo/weapon HUD and sprint toggle.
- MTU-safe FastLZ snapshot transport with 900-byte chunks.
- Server-authoritative movement, damage, health, ammo, zombies and campaign progression.
- Game Over/Restart hardening for applicable local gameplay flows.
- Day/night visual cycle and Android performance tiers.
- Reproducible Android generated-template sanitization for redundant Manifest merger directives.

## Compatibility

- App version: `0.9.0-beta.5`
- Version code: `900005`
- Network protocol: `2`
- Content version: `1`
- Minimum compatible client/server version code: `900005`
- Target Android API: `36`
- Maximum squad size: `4`

Beta.5 intentionally rejects beta.4 and older gameplay clients/servers because the orchestrated match lifecycle and reconnect semantics changed.

## Validation status

Source-side lifecycle gates are part of the current candidate, including admission-schema, heartbeat/result IPC, safe health telemetry, MTU inheritance and real ticket-reconnect orchestration checks. The candidate is not considered physically accepted until the current VPS `--tests-only`, full `--force` deployment, signed APK installation and multi-device Internet/reconnect/result-to-lobby tests pass.

Voice chat remains outside this candidate.

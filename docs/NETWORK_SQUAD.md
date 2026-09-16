# Four-player Squad

Phase 7 expands the Phase 6 authoritative network slice from Duo to a maximum of four gameplay peers without creating a second networking stack. The existing `DuoNetworkSession.gd` filename remains for compatibility, but its protocol is now Squad-capable.

## Capacity and identity

- Protocol version: 2.
- Maximum active gameplay peers: 4.
- Four player spawn slots: A/B/C/D.
- Stable gameplay `entity_id` remains separate from transient ENet `peer_id`.
- Reconnect grace: 45 seconds.
- A valid reconnect reservation owns its previous slot during the grace window, so new peers cannot displace a temporarily disconnected squad member.
- Room directory resolution advertises `max_players: 4` alongside the protocol and gameplay endpoint.

## Life state

Network players use an authoritative `PlayerLifeState`:

`ALIVE -> DOWNED -> DEAD`

The normal damage path remains `DamageEvent -> Authority -> HealthComponent`. `HealthComponent` may call the player's lethal interceptor before emitting final death. The first eligible lethal hit changes an ALIVE network player to DOWNED and keeps minimal positive HP. A lethal follow-up or bleedout produces final DEAD.

Defaults:

- Bleedout: 30 seconds.
- Revive hold: 3 seconds.
- Revive range: 2.4 m.
- Revived health: 35%.
- Downed movement: 35% and prone presentation.
- DOWNED/DEAD cannot fire or reload.

## Revive trust boundary

The client sends only a continuous sanitized `interact` flag inside `PlayerCommand`. It never sends a trusted revive target or revive completion. The server finds the nearest DOWNED teammate in range, accumulates the hold duration, cancels progress if range/input/state becomes invalid, and calls `revive_authoritative()` only after the server timer completes.

## Horde scaling

Squad size increases scheduled wave size and the simultaneous population budget, but not linearly. Four players do not receive four times the active AI load.

Wave multipliers for 1–4 players are currently:

- 1 player: 1.00x
- 2 players: 1.35x
- 3 players: 1.65x
- 4 players: 1.90x

Each quality profile adds a bounded per-extra-member population bonus. Spawn safety treats DOWNED players as recoverable squad members, and Horde enters GAME_OVER only when no registered player is recoverable.

## Replication budgets

Every client receives all four player states and the authoritative Horde summary, but detailed zombie snapshots are personalized by distance from that client. A lightweight `zombie_ids` list distinguishes an irrelevant zombie from a destroyed/despawned zombie.

Current quality budgets:

| Tier | Detailed zombies | Snapshot Hz | Max estimated payload |
|---|---:|---:|---:|
| Smooth | 12 | 12 | 24 KB |
| Standard | 18 | 15 | 32 KB |
| Ultra | 24 | 18 | 40 KB |
| Ultra HD | 32 | 20 | 48 KB |

If the estimated Variant payload exceeds the tier budget, farthest zombie details are removed until it fits. Player/Horde state is never removed by this trimming step.

## Squad HUD and Android

The client adds a Squad HUD showing up to four members with HP, DOWN bleedout, revive progress or DEAD. Android exposes a REVIVE touch control mapped to `interact` and prints `DEADFALL_SQUAD_STATS` with capacity and replication budgets.

## Validation

- `scripts/ci/network_smoke.gd`: client authority rejection, command sanitation/sequencing, room-code protocol/capacity payloads and server weapon regressions.
- `scripts/ci/squad_smoke.gd`: downed, revive, bleedout, weapon lock, reconnect-slot capacity, replication budgets, four-player Horde scaling and server-held revive.
- `scripts/ci/duo_integration.sh`: two-peer backward-regression integration.
- `scripts/ci/squad_integration.sh`: one headless server plus four real ENet clients; every client must observe `DEADFALL_SQUAD_SNAPSHOT players=4`.

Execution of the new current-head gates remains dependent on GitHub Actions billing/spending being available. Physical four-phone Android soak, latency, reconciliation and FPS profiling remains a separate acceptance gate.

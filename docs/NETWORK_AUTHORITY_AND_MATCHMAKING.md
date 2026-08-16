# NEXORA: DEADFALL — Network Authority and Matchmaking

## Core trust boundary

The Android client is never trusted as the source of truth for gameplay state.

The client may submit **intent only**:

- movement vector;
- yaw/pitch intent;
- sprint/interact state;
- jump/crouch/prone serials;
- fire/reload request serials;
- match admission ticket during the initial join handshake.

The client does **not** submit trusted values for:

- world position;
- velocity as authority;
- health;
- damage amount;
- victim ID / hit result;
- ammo count;
- reload completion;
- zombie state;
- Horde/Campaign progression.

`PlayerCommand.gd` validates and sanitizes the accepted command shape. `ClosedBetaNetworkSession.gd` applies rate limits and payload limits before forwarding a command to the server-owned player node.

## Server-owned movement

For a remote player the dedicated match process owns a real `Player` node in `SERVER_REMOTE` control mode. The server receives the sanitized input command, applies authoritative orientation and stance rules, calculates velocity and executes `move_and_slide()` in the server physics world.

The client may predict its own movement for responsiveness, but every snapshot contains the server position/velocity and the predicted player is reconciled to that state.

A stale-input watchdog neutralizes the last remote movement command after approximately 350 ms without a fresh command. This prevents a player from continuing to walk indefinitely after abrupt packet loss or Internet loss.

## Server-owned combat, health and ammo

Fire packets contain a request sequence and client tick; they do not contain a trusted origin, direction, victim or damage value.

The server-owned weapon:

1. validates cadence and authoritative ammo;
2. reads the server player's current aim camera transform;
3. performs the physics raycast in the server world;
4. determines the authoritative hitbox/body part;
5. creates the damage event with weapon data owned by the game;
6. resolves damage through `Game.authority`;
7. replicates resulting health/ammo/life state to clients.

This architecture blocks the common direct forms of position, infinite-health, arbitrary-damage, infinite-ammo and forged-hit packet manipulation. It does not make the game universally cheat-proof; server-side anomaly detection, telemetry and validation should continue to be expanded as new mechanics are introduced.

## Party-to-match guarantee

A social party is not itself a gameplay server. When the leader starts a Duo/Squad match, `MatchOrchestrator`:

1. snapshots the authoritative current party membership;
2. allocates one unused UDP port in `24600–24749`;
3. creates one `match_id` for the entire party;
4. generates one cryptographically random 64-hex admission ticket per member;
5. writes the isolated match admission config;
6. launches one child Godot dedicated process for that party;
7. waits for the child process to publish its real readiness marker after ENet and the arena are initialized;
8. publishes the **same match ID, host and port** to every party member;
9. exposes only the requesting member's private join ticket in that member's party snapshot.

Therefore members of the same party do not independently search for a server. They all receive one reserved instance and enter that same process.

Knowing the IP and UDP port is not sufficient to join an orchestrated match. The child match requires a valid ticket from its admission config and rejects missing, invalid or already-in-use tickets before creating a gameplay entity.

Party membership is locked while a match is STARTING, READY or IN_MATCH, preventing membership changes from racing against the reserved admission list.

## Match process lifecycle

The control server monitors child PIDs. Match instances also contain a local lifecycle guard:

- startup grace: 90 seconds;
- empty-after-use grace: 75 seconds;
- absolute match lifetime: 2 hours.

The parent control process cleans stale match assignments and admission files when a child exits. A control-server shutdown terminates its child match processes instead of orphaning them.

A later milestone should replace the current file-based readiness/lifecycle signaling with richer process heartbeats so the parent can expose authoritative `IN_MATCH`, mission completion and crash diagnostics in real time.

## Ping semantics

`NetworkTelemetry` is visible throughout the client:

- outside a match it measures HTTPS/control-server RTT;
- inside an ENet match the dedicated-server ping channel becomes the preferred measurement;
- match ping uses an independent `unreliable_ordered` channel and does not block movement/fire traffic;
- if the most recent pong becomes stale, the indicator reports no connection.

Display behavior:

- raw RTT `<= 25 ms` → display `0`, quality `EXCELENTE`;
- `26–70 ms` → actual value, `BUENO`;
- `71–140 ms` → actual value, `MEDIO`;
- `> 140 ms` → actual value, `ALTO`;
- no usable connectivity → `+999`, `SIN CONEXIÓN`.

The social presence snapshot also carries the player's reported display ping so squad/friend UI can show a lightweight network status. This is cosmetic presence information; it must never be used as a trusted gameplay authority signal.

## Current bandwidth/latency optimizations

The existing networking already applies several optimizations:

- client prediction with authoritative reconciliation;
- interpolation for remote replicas;
- server snapshots on `unreliable_ordered` transport;
- configurable snapshot frequency rather than physics-tick replication;
- nearest/relevant zombie detail selection per receiving player;
- zombie detail budget;
- maximum snapshot payload budget with detail trimming;
- compact whitelisted input commands instead of full player transforms;
- separate reliable RPCs for one-shot actions such as fire/reload/join;
- separate unreliable ping traffic;
- isolated 1–4 player match processes so unrelated parties do not share replica traffic.

## Network optimizations still planned

Do not claim these as implemented yet:

- delta/bit-packed snapshot encoding;
- bandwidth counters by RPC/snapshot category;
- adaptive command coalescing/heartbeat while preserving action serials;
- adaptive per-peer snapshot rate based on loss/RTT and relevance;
- region-aware matchmaking when multiple VPS regions exist;
- explicit packet-loss/jitter display and diagnostics;
- richer server-side movement/fire anomaly scoring;
- child-process heartbeat/IN_MATCH/mission-complete IPC;
- reconnect tickets scoped to orchestrated match identity.

Any optimization must preserve server authority and must be validated against real Android devices before reducing update frequency or changing reconciliation thresholds.

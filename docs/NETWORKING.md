# Networking model

## Topology

Dedicated server authority on a public VPS. Clients do not host production matches and do not need inbound port forwarding.

```text
Android clients -- ENet/UDP --> Dedicated Godot server --> Shared simulation
```

Default development port: `24560/udp`.

## Server owns

- Accepted player position/state corrections.
- Damage and hit validity.
- Zombie AI and target selection.
- Zombie/player health and death.
- Spawns, drops and wave state.
- Objectives, score and match result.

Clients submit input and shot intent. They do not submit final damage or kill decisions.

## Target timing model

Initial targets, to be profiled before locking:

- Local rendering: up to device frame target, normally 60 FPS.
- Physics/simulation: 60 Hz in the project baseline.
- Server network snapshot target: 10–20 Hz.
- Server gameplay processing target: 20–30 Hz where decoupling is appropriate.

Movement prediction and server reconciliation are required for the local player. Remote entities use buffered interpolation. Exact rates are performance parameters, not promises, until multiplayer profiling begins.

## Rooms

First public test implementation: closed room code of 4–6 characters, max four players. A small control API may later map room codes to active server instances. The game server itself remains isolated from unrelated VPS services.

## Security principles

- Never trust client health, inventory, score or kill claims.
- Rate-limit RPC/input traffic.
- Validate sequence/tick windows.
- Validate weapon fire cadence and ammunition.
- Reject impossible movement deltas.
- Keep protocol versioning explicit.
- Log server-side match events needed for debugging without logging secrets.

## Reconnection

Reconnection is a required later milestone. The server should retain a disconnected player's match slot for a short grace interval and restore authoritative state after identity validation.

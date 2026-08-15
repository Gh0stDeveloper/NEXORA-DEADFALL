# Multiplayer Duo

Phase 6 introduces the first two-player network slice while preserving the authority boundary established in Phases 2–5.

## Authority model

The dedicated server owns movement validation, firearm cadence/ammunition/reload, hitscan, damage, zombie AI and Horde progression. Network clients own input collection, local presentation and prediction only. `NetworkAuthority.resolve_damage()` always rejects client-side damage.

## Transport

- ENet gameplay UDP: default `24560`.
- Room directory TCP/HTTP: default `24561`.
- Maximum gameplay peers: 2.
- Input commands: unreliable ordered channel 0.
- Server snapshots: unreliable ordered channel 1 at 15 Hz.
- Join, fire, reload and restart requests: reliable channel 2 where appropriate.

A fire request contains only a monotonically increasing request sequence and client tick. It does not contain trusted damage, victim ID, hit result or ammo state. The server weapon builds the authoritative shot from the server-side player/camera transform and applies its own `WeaponRuntimeState` cadence/ammo/reload gates.

## Player movement

The client predicts the local player using the same controller values. Commands carry normalized movement, sprint state, absolute yaw/pitch and monotonic action serials. The server rejects stale sequences and simulates collision/movement on its own `CharacterBody3D`. Snapshots contain authoritative position, velocity, stance and acknowledged command sequence. Small prediction error is corrected smoothly; large divergence hard-snaps.

Remote players use snapshot interpolation and never process local input or weapon input.

## Horde and zombies

`HordeDirector` now supports a dynamic player registry. Spawn safety checks every living registered player, and Game Over occurs only when no registered player remains alive. On the dedicated server the director is given `DedicatedAuthority`; on clients Horde snapshots are presentation-only.

## Room codes

Each dedicated-server process exposes one six-character room code. The lightweight directory endpoint responds to `GET /room/<CODE>` with protocol, advertised host and ENet gameplay port. Production deployments should publish the directory through HTTPS/reverse proxy and set `--public-host` to the externally reachable DNS name/IP.

Example server:

```bash
godot --headless --path . -- --server --port=24560 --directory-port=24561 --public-host=game.example.com --room=AB2CD3
```

Direct client:

```bash
godot --path . -- --connect=game.example.com:24560 --name=PlayerOne
```

Room lookup client:

```bash
godot --path . -- --room=AB2CD3 --directory=https://directory.example.com --name=PlayerOne
```

## Reconnect groundwork

The server issues a cryptographically random resume token. A disconnected peer reserves its entity ID and authoritative player snapshot for 20 seconds. The client stores the token under `user://duo_resume_token.txt` and presents it on the next connection. Expired reservations are discarded.

## Tests

- `scripts/ci/network_smoke.gd`: client authority rejection, command sanitation/sequencing, room-code payloads and DuoArena contract.
- `scripts/ci/duo_integration.sh`: boots one headless dedicated server plus two real ENet clients and requires both clients to observe a two-player snapshot.

Current GitHub Actions execution remains dependent on the account billing/spending block being cleared.

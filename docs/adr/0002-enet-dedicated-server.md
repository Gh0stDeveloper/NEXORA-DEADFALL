# ADR 0002 — ENet/UDP dedicated server as primary multiplayer transport

**Status:** Accepted  
**Date:** 2026-08-15

## Context

NEXORA: DEADFALL needs low-latency 2–4 player co-op and has access to a public VPS. Clients should not require inbound port forwarding and must not own authoritative combat outcomes.

## Decision

Use Godot `ENetMultiplayerPeer` over UDP with a headless dedicated server as the initial multiplayer topology. The first development port is `24560/udp`.

## Consequences

- The VPS must expose the selected UDP port.
- Server instances need CPU/RAM isolation and logging.
- Client prediction/interpolation/reconciliation are required later.
- WebSocket/WebRTC/relay transports are deferred until a measured network compatibility problem justifies them.

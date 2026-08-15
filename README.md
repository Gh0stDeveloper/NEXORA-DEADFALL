# NEXORA: DEADFALL

Mature-rated zombie survival shooter for Android, built with **Godot 4.6.3 stable**.

## Vision

NEXORA: DEADFALL combines campaign missions, standard objective matches and endless horde survival with offline play and server-authoritative online co-op for 2–4 players. The project is Android-first, landscape-only, and designed around scalable 3D rendering, limb-based damage and gore that remains mechanically meaningful across quality tiers.

## Current status

**Phase 0 — Technical foundation.**

This repository currently contains the production-oriented project skeleton, shared simulation boundaries, a local authority implementation, the first damage event model, an ENet dedicated-server bootstrap, CI smoke checks, Android export scaffolding and Ubuntu/Docker deployment definitions.

## Engine baseline

- Godot: `4.6.3-stable`
- Scripting: GDScript
- Client target: Android, ARM64 first
- Server target: Ubuntu 24.04 LTS / Docker
- Primary multiplayer transport: ENet over UDP
- Default game port: `24560/udp`

## Repository layout

```text
src/
  autoload/          Global orchestration and settings
  core/              Simulation contracts independent of transport
    authority/       Local/network authority boundary
    damage/          Damage event and resolution foundation
  main/              Application bootstrap scene
  server/            Dedicated server runtime
scripts/
  ci/                Headless validation scripts
  server/            Local/VPS launch helpers
deploy/
  docker/            Dedicated server container
  systemd/           Ubuntu service unit
docs/                Living GDD and technical documentation
.github/workflows/    CI and Android build automation
```

## Documentation

- [Game Design Document](docs/GDD.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Networking](docs/NETWORKING.md)
- [Android](docs/ANDROID.md)
- [Ubuntu/VPS server](docs/SERVER_UBUNTU.md)
- [Quality gates](docs/QUALITY_GATES.md)
- [Roadmap](docs/ROADMAP.md)

## Development rule

Gameplay systems must not branch into separate online and offline implementations. Offline uses local authority; online uses network authority backed by the dedicated server. Damage, AI, weapons, waves, objectives and match rules remain part of the same simulation model.

## License

Proprietary software. Copyright © Ghost Developer / Nexora. All rights reserved. See [LICENSE.md](LICENSE.md).

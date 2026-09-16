# Ubuntu / VPS dedicated server

## Supported baseline

Primary server target: Ubuntu 24.04 LTS x86_64, either directly under systemd or inside Docker.

## Network

Open the configured game port as UDP only. Initial default:

```text
24560/udp
```

Do not expose unrelated management ports publicly. SSH access should use the VPS owner's existing hardening policy.

## Direct service layout

Recommended paths:

```text
/opt/nexora-deadfall
/usr/local/bin/godot
```

Create a dedicated unprivileged `deadfall` service account, place the repository/export under `/opt/nexora-deadfall`, install `deploy/systemd/nexora-deadfall.service`, then enable it with systemd.

## Docker

From repository root:

```bash
docker compose -f deploy/docker/docker-compose.yml up -d --build
```

The container is intentionally isolated from other Nexora services and has example CPU/RAM limits in Compose. Tune those limits using real match telemetry.

## Health verification

During early development, validate:

- process/container remains running;
- UDP socket is bound on the configured port;
- server log reports successful ENet startup;
- a client can connect and disconnect cleanly;
- memory does not grow across repeated match cycles.

## Logging

Use journald for systemd or Docker logs for containerized deployment. Match IDs should be added before multiplayer beta so crash/bug reports can be correlated with server events.

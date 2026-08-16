# Phase 10/11 — VPS production installer

The VPS is the DEADFALL control/social server, match orchestrator, dedicated game-instance host and Android Closed Beta build host. Supported baseline: Ubuntu 24.04, x86_64 or ARM64.

## First installation

1. Create DNS `A` (or `AAAA`) for the public DEADFALL domain pointing to the VPS.
2. Install GitHub CLI access for the private repositories when prompted. The `deadfall` service user needs read access to both `Gh0stDeveloper/NEXORA-DEADFALL` and the provisional model repository `Gh0stDeveloper/Objetos3D`.
3. From a clone/copy of this repository run:

```bash
sudo bash deploy/vps/install.sh \
  --domain beta.example.com \
  --email admin@example.com \
  --repo Gh0stDeveloper/NEXORA-DEADFALL \
  --branch main
```

For the current development branch use `--branch agent/bootstrap-deadfall`.

If the VPS cannot use interactive device login, authenticate first as the service user after the base packages are installed, or provide `--github-token-file /root/github-token.txt`; delete that token file after use.

```bash
sudo -Hu deadfall gh auth login --hostname github.com --git-protocol https
sudo -Hu deadfall gh auth setup-git --hostname github.com
sudo -Hu deadfall gh auth status --hostname github.com
```

The installer intentionally uses no `--skip-ssh-key` flag. HTTPS Git authentication does not need SSH key creation.

## Interrupted/partial installation recovery

The installer is designed to be rerun. If it stops after installing packages but before cloning `/opt/nexora-deadfall`, generating the keystore or creating services, do not delete the VPS and do not reinstall Godot/Android manually.

```bash
cd ~/NEXORA-DEADFALL
git pull --ff-only origin agent/bootstrap-deadfall

sudo bash deploy/vps/install.sh \
  --domain beta.example.com \
  --email admin@example.com \
  --repo Gh0stDeveloper/NEXORA-DEADFALL \
  --branch agent/bootstrap-deadfall
```

If Ubuntu reports `/var/run/reboot-required`, finish/verify the installation first and then reboot the VPS to load the new kernel. The installer never reboots the machine automatically.

## What the installer/update stack does

- Detects first install versus existing managed state.
- Installs Godot 4.6.3 plus export templates.
- Installs JDK 17 and Android SDK API 35/36, Build Tools 35.0.1/36.0.0, NDK r28b and CMake.
- Installs Node.js 24 LTS, Nginx, Certbot and GitHub CLI.
- Generates `/etc/nexora-deadfall/signing/deadfall-release.keystore` once; normal updates never replace it.
- Synchronizes provisional runtime `.glb` models from `Gh0stDeveloper/Objetos3D` before Godot import/export. ZIP source packages are not copied.
- Builds/verifies the signed APK and atomically publishes `/var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk`.
- Builds the Next.js portal on `127.0.0.1:3100` behind Nginx.
- Runs the control/social/match-orchestration API only on `127.0.0.1:24562`; Nginx publishes it under `/api/deadfall/`.
- Keeps the legacy/base ENet server on UDP 24560 and room directory on TCP 24561.
- Allocates isolated orchestrated match instances from UDP `24600–24749`. Each party receives one match instance; each member receives a private admission ticket.

Back up `/etc/nexora-deadfall/signing/` securely. Losing this keystore means future APK updates cannot retain the same signing identity.

## Daily commands

```bash
nexora-deadfall status
nexora-deadfall update
nexora-deadfall build-app
nexora-deadfall build-web
nexora-deadfall build-all
nexora-deadfall logs 200
nexora-deadfall https
```

`nexora-deadfall update` fetches the configured private branch, synchronizes provisional models when game/server surfaces changed, runs Godot smokes, rebuilds affected artifacts, restarts services and verifies the localhost/public API before recording a successful deploy.

## Match networking

The public gameplay surface is UDP only:

- `24560/udp` — legacy/base gameplay instance.
- `24600:24749/udp` — orchestrated party match instances.
- `24561/tcp` — legacy room directory.
- `80/tcp` and `443/tcp` — portal and HTTPS control/social API.

`24562/tcp` must **not** be opened publicly. It is intentionally bound to localhost and reached through Nginx HTTPS.

The orchestrator writes a per-match admission file under Godot server state, launches a child Godot process on an unused UDP port, waits for the child to publish a real readiness marker, then returns the same `match_id`, host and port to all members. Join tickets are unique per member and are never included in another member's party snapshot.

## Firewall

UFW is configured for SSH, 80/tcp, 443/tcp, 24560/udp, 24561/tcp and the orchestrated range `24600:24749/udp`.

Cloud-provider firewall/security-list rules must also allow:

```text
TCP 80
TCP 443
UDP 24560
UDP 24600-24749
```

Expose TCP 24561 only if the legacy directory path is still being used externally. Do not expose TCP 24562.

For Oracle Cloud, update the VCN/subnet Security List or NSG as well as UFW; opening UFW alone does not make the dynamic match ports reachable from the Internet.

## Model synchronization

Production/VPS updates use:

```bash
sudo -Hu deadfall bash /opt/nexora-deadfall/scripts/assets/sync_objetos3d.sh /opt/nexora-deadfall
```

Canonical runtime mappings are staged in:

```text
assets/external/objetos3d/operator_01.glb
assets/external/objetos3d/operator_02.glb
assets/external/objetos3d/zombie_animated.glb
assets/external/objetos3d/zombie_static.glb
```

Those binaries are generated/staged and ignored by the main repository. If a model is unavailable, gameplay scenes keep their built-in fallback visual instead of failing to load.

## Important paths

- Repository: `/opt/nexora-deadfall`
- Persistent state/builds/match configs: `/var/lib/nexora-deadfall`
- Config/secrets: `/etc/nexora-deadfall`
- Public APK metadata: `/var/www/nexora-deadfall`
- Logs: `/var/log/nexora-deadfall`
- Service units: `nexora-deadfall.service`, `nexora-deadfall-download.service`

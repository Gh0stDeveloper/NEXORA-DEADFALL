# NEXORA: DEADFALL

Android-first zombie survival shooter built with **Godot 4.6.3**, with offline Campaign/Horde and server-authoritative online co-op for up to four players.

## Current status

The repository now contains the gameplay vertical slice through **Phase 9 Closed Beta hardening** plus **Phase 10 VPS production automation**:

- Player movement, mobile controls and FPS/TPS cameras.
- Authoritative weapons, damage and body hit zones.
- Zombie AI, dismemberment/gore and Horde director.
- 1–4 player ENet Squad with prediction/interpolation, DOWNED/revive and reconnect.
- Campaign vertical slice with two missions and hardened checkpoints.
- Closed Beta build/version handshake, abuse guards and diagnostics.
- Ubuntu VPS installer/updater that hosts the dedicated server, compiles signed Android Release APKs and serves the beta download portal.

## Engine / production baseline

- Godot: `4.6.3-stable`
- Client: Android ARM64, Closed Beta `0.9.0-beta.1`
- VPS: Ubuntu 24.04 LTS, x86_64 or ARM64
- Game: `24560/udp`
- Room directory: `24561/tcp`
- Download portal: Next.js 16 / TypeScript behind Nginx
- Web: `80/tcp` and `443/tcp`

# Clean VPS — first installation

The repository is private, so a brand-new VPS needs GitHub authentication once before it can obtain the installer.

## 1. Install Git + GitHub CLI

```bash
sudo apt update
sudo apt install -y git gh
```

## 2. Log in to GitHub once

```bash
gh auth login --hostname github.com --git-protocol https
gh auth setup-git --hostname github.com
gh auth status --hostname github.com
```

Choose GitHub.com and HTTPS. GitHub CLI stores the credential and configures Git as a credential helper, so normal future fetch/pull operations do not require logging in again.

## 3. Clone the private repository

```bash
cd ~
gh repo clone Gh0stDeveloper/NEXORA-DEADFALL
cd NEXORA-DEADFALL
```

Until the current draft PR is merged, install the active development branch:

```bash
git checkout agent/bootstrap-deadfall
```

Once Phase 10 is merged, production should use `main`.

## 4. Point a domain at the VPS

Create a DNS `A` record (and `AAAA` if you use public IPv6) such as:

```text
beta.example.com -> VPS_PUBLIC_IP
```

The same domain is used for the mobile download page and the stable APK URL.

## 5. Run the complete installer

Current development branch:

```bash
sudo bash deploy/vps/install.sh \
  --domain beta.example.com \
  --email admin@example.com \
  --repo Gh0stDeveloper/NEXORA-DEADFALL \
  --branch agent/bootstrap-deadfall
```

After merge:

```bash
sudo bash deploy/vps/install.sh \
  --domain beta.example.com \
  --email admin@example.com \
  --repo Gh0stDeveloper/NEXORA-DEADFALL \
  --branch main
```

The installer creates its own `deadfall` service user. If that account is not yet authenticated, the installer starts the GitHub device-login flow for it and then runs `gh auth setup-git` so future automatic updates can read the private repo.

For headless/token bootstrap you may use:

```bash
sudo bash deploy/vps/install.sh --github-token-file /root/github-token.txt ...
sudo rm -f /root/github-token.txt
```

Do not keep PAT/token files on disk after bootstrap.

# What the installer configures

On a clean Ubuntu VPS it installs and configures:

- Godot 4.6.3 for x86_64 or ARM64, including export templates.
- OpenJDK 17.
- Android command-line tools, API 35 + 36, Build Tools 35.0.1, NDK r28b and CMake.
- Node.js 24 LTS.
- GitHub CLI and persistent private-repo Git credentials.
- Nginx and Certbot.
- Dedicated game service.
- Next.js beta download service.
- Stable public APK directory.
- Persistent install/build state and logs.
- Firewall rules for SSH, HTTP/HTTPS and DEADFALL multiplayer ports.

It detects an existing installation and preserves persistent state.

# Android signing keystore

On the **first** installation only, the installer generates:

```text
/etc/nexora-deadfall/signing/deadfall-release.keystore
/etc/nexora-deadfall/signing/keystore.env
```

The updater never regenerates or replaces that keystore automatically.

**Back up `/etc/nexora-deadfall/signing/` somewhere secure.** Losing the signing key means future APK updates cannot keep the same Android signing identity.

The persistent key remains root-only. During a build, a temporary `0600` copy is exposed only to the `deadfall` build user, then deleted after signing/verification.

# One-command future updates

```bash
nexora-deadfall update
```

The updater:

1. validates stored GitHub auth;
2. fetches the configured private branch;
3. compares old and new commits;
4. classifies changed files;
5. runs Godot import/smoke gates for gameplay/server changes;
6. rebuilds the signed APK only when app/shared gameplay changed;
7. rebuilds the Next.js portal only when needed;
8. restarts only affected services;
9. atomically publishes the new APK and metadata.

Shared files under `src/` affect both client and dedicated server and therefore rebuild/restart both sides. A web-only change does not rebuild the game. Documentation-only changes cause no runtime rebuild.

Force a complete rebuild when required:

```bash
sudo /opt/nexora-deadfall/deploy/vps/update.sh --force
```

# VPS administration

```bash
nexora-deadfall status
nexora-deadfall update
nexora-deadfall build-app
nexora-deadfall build-web
nexora-deadfall build-all
nexora-deadfall logs 200
nexora-deadfall auth
nexora-deadfall https
```

Services:

```bash
sudo systemctl status nexora-deadfall
sudo systemctl status nexora-deadfall-download
sudo systemctl status nginx
```

# APK download

A successful application build publishes:

```text
https://YOUR_DOMAIN/downloads/NEXORA-DEADFALL-latest.apk
```

The Next.js home page reads `/var/www/nexora-deadfall/release.json` at request time and shows current version, APK size and SHA-256 before presenting the download button.

# Important VPS paths

```text
/opt/nexora-deadfall                  private Git checkout
/var/lib/nexora-deadfall             persistent runtime/build state
/etc/nexora-deadfall                 configuration + signing secrets
/var/www/nexora-deadfall             public release metadata/APK
/var/log/nexora-deadfall             service/build logs
/usr/local/bin/nexora-deadfall       administration command
```

Full VPS documentation: [docs/VPS_INSTALLER.md](docs/VPS_INSTALLER.md).

## Documentation

- [Game Design Document](docs/GDD.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Networking](docs/NETWORKING.md)
- [Campaign](docs/CAMPAIGN.md)
- [Closed Beta hardening](docs/BETA_HARDENING.md)
- [VPS installer](docs/VPS_INSTALLER.md)
- [Roadmap](docs/ROADMAP.md)

## Development rule

Gameplay systems must not branch into separate online/offline implementations. Offline uses local authority; online uses network authority backed by the dedicated server. Deployment automation must not create a second gameplay implementation.

## License

Proprietary software. Copyright © Ghost Developer / Nexora. All rights reserved. See [LICENSE.md](LICENSE.md).

# Phase 10 — VPS production installer

The VPS is both the dedicated game server and the Android Closed Beta build host. Supported baseline: Ubuntu 24.04, x86_64 or ARM64.

## First installation

1. Create DNS `A` (or `AAAA`) for the download domain pointing to the VPS.
2. Install GitHub CLI access for the private repository when prompted by the installer. GitHub recommends `gh auth login` and `gh auth setup-git` for persistent HTTPS Git credentials.
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

## What the installer does

- Detects a first install versus `/var/lib/nexora-deadfall/install-state.json`/existing Git checkout.
- Installs Godot 4.6.3 for the VPS architecture plus export templates.
- Installs JDK 17 and Android SDK command-line tools, API 35/36, Build Tools 35.0.1, NDK r28b and CMake.
- Installs Node.js 24 LTS, Nginx, Certbot and GitHub CLI.
- Generates `/etc/nexora-deadfall/signing/deadfall-release.keystore` once. Updates never replace it.
- Builds/verifies the signed ARM64 APK and atomically publishes it at `/var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk`.
- Builds the Next.js standalone portal and runs it on `127.0.0.1:3100` behind Nginx.
- Starts the Godot dedicated server on UDP 24560 and room directory on TCP 24561.

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

`nexora-deadfall update` fetches the configured private branch, compares old/new commits and rebuilds only affected surfaces. Shared gameplay changes under `src/` rebuild/restart both app and server; web-only changes rebuild only the portal; docs-only changes require no runtime rebuild.

## Domain and HTTPS

Nginx serves the portal on ports 80/443 and serves the APK directly under `/downloads/`. Certbot is invoked automatically when both domain and email are supplied; if DNS is not ready, rerun later with `nexora-deadfall https`.

## Firewall

The installer allows SSH, 80/tcp, 443/tcp, 24560/udp and 24561/tcp in UFW. Cloud-provider firewall/security-list rules must allow the same public ports where appropriate.

## Important paths

- Repository: `/opt/nexora-deadfall`
- Persistent state/builds: `/var/lib/nexora-deadfall`
- Config/secrets: `/etc/nexora-deadfall`
- Public APK metadata: `/var/www/nexora-deadfall`
- Logs: `/var/log/nexora-deadfall`
- Service units: `nexora-deadfall.service`, `nexora-deadfall-download.service`

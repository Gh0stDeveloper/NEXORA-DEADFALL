# NEXORA: DEADFALL — VPS production installer/runbook

Last updated: 2026-08-17.

The managed VPS is the DEADFALL control/social server, match orchestrator, dedicated game-instance host, Android Closed Beta build host and download-portal host.

Supported baseline: Ubuntu 24.04, x86_64 or ARM64.

## Current production baseline

- Godot `4.6.3-stable` plus export templates.
- JDK 17.
- Android SDK API 35/36.
- Current Android build automation baseline uses Build Tools `36.1.0` where required by the Godot 4.6.3 export flow.
- NDK r28b/CMake support.
- Node.js 24.
- Nginx/Certbot.
- GitHub CLI.
- Current Closed Beta: `0.9.0-beta.5 / 900005`.

Last confirmed full runtime deployment:

```text
f402f1696c0438447d76236122a5d82101a94cc0
```

## First installation

1. Point the intended public domain to the VPS with DNS `A` and optional `AAAA` records.
2. Ensure GitHub access to the private main repository and `Gh0stDeveloper/Objetos3D`.
3. Run the installer from a clone/copy of the repository.

Current development branch:

```bash
sudo bash deploy/vps/install.sh \
  --domain beta.example.com \
  --email admin@example.com \
  --repo Gh0stDeveloper/NEXORA-DEADFALL \
  --branch agent/bootstrap-deadfall
```

After an explicitly approved merge, `main` may be used instead. Do not assume PR #1 has been merged.

### GitHub authentication

The managed `deadfall` service user needs persistent repository read access for later automatic updates:

```bash
sudo -Hu deadfall gh auth login --hostname github.com --git-protocol https
sudo -Hu deadfall gh auth setup-git --hostname github.com
sudo -Hu deadfall gh auth status --hostname github.com
```

For headless bootstrap, the installer may receive a temporary token file. Remove it after bootstrap.

Do not store PATs/tokens in this repository.

## Interrupted/partial installation recovery

The installer is intended to be rerunnable. Do not rebuild the VPS from scratch or manually install competing Godot/Android versions merely because one installer run was interrupted.

Update the bootstrap clone and rerun:

```bash
cd ~/NEXORA-DEADFALL
git pull --ff-only origin agent/bootstrap-deadfall

sudo bash deploy/vps/install.sh \
  --domain beta.example.com \
  --email admin@example.com \
  --repo Gh0stDeveloper/NEXORA-DEADFALL \
  --branch agent/bootstrap-deadfall
```

If Ubuntu reports `/var/run/reboot-required`, finish/verify the managed installation first and reboot afterwards. The installer does not reboot automatically.

## What the installer/update stack manages

- first-install vs existing-install detection;
- Godot/export templates;
- Java/Android SDK/toolchain;
- Node/Nginx/Certbot/GitHub CLI;
- private Git authentication;
- persistent Android signing identity;
- staged external 3D models;
- Godot import/validation gates;
- signed APK build/verification/publication;
- Next.js portal build;
- systemd services;
- Nginx/HTTPS;
- base dedicated service;
- control/social/match API;
- dynamic party match child processes;
- differential update classification.

A web-only change must not force an Android rebuild. Application/shared gameplay/build changes should rebuild/revalidate the corresponding runtime surfaces.

## Android signing identity

First installation creates persistent signing material under:

```text
/etc/nexora-deadfall/signing/
```

The normal updater must never regenerate/replace it.

Back it up securely. Losing the signing key prevents future APKs from retaining the same Android update identity.

During a build, only a temporary restricted copy is exposed to the build user and removed afterwards.

## Generated Android template hardening

Godot regenerates Android build files, so production fixes are implemented in source automation rather than manual edits under `/opt/nexora-deadfall/android/build`.

Current build pipeline:

- applies `android.suppressUnsupportedCompileSdk=36` reproducibly;
- sanitizes only the four known redundant Godot Manifest `tools:replace` attributes;
- runs the sanitizer immediately before the relevant Manifest merge through the managed Gradle init hook;
- validates the patch with `scripts/ci/android_template_patch_smoke.sh`;
- verifies the final APK with `apksigner`.

Do not add ad-hoc edits directly to generated Android build output as the permanent fix.

## External model synchronization

Source repository:

```text
Gh0stDeveloper/Objetos3D
```

Pinned submodule commit for the current model baseline:

```text
28ea7a10a18fbe05a91fb3d920678991fff4afef
```

Production/VPS staging:

```bash
sudo -Hu deadfall bash /opt/nexora-deadfall/scripts/assets/sync_objetos3d.sh /opt/nexora-deadfall
```

Canonical runtime mappings:

```text
assets/external/objetos3d/operator_01.glb
assets/external/objetos3d/operator_02.glb
assets/external/objetos3d/zombie_animated.glb
assets/external/objetos3d/zombie_static.glb
```

The staging script validates GLB inputs before Godot import. Do not bypass it with manual production copies.

## Network layout

Public gameplay/web:

```text
80/tcp
443/tcp
24560/udp
24600-24749/udp
```

Additional services:

```text
24561/tcp  room directory when required
24562/tcp  control/social/match API — localhost only
```

Never expose TCP 24562 directly. Nginx publishes the required API surface through HTTPS.

### Dynamic MatchOrchestrator

For an online party start:

1. parent server snapshots the authoritative party;
2. one `match_id` is created;
3. one port is allocated from UDP `24600-24749`;
4. one dedicated child Godot process is launched;
5. each member gets a distinct 256-bit ticket;
6. child loads MatchAdmission and publishes READY;
7. parent distributes same host/port/match ID plus each member's own ticket;
8. child heartbeat/result files let the parent supervise lifecycle.

Beta.5 additionally provides:

- same-ticket authoritative reconnect;
- 2-second child heartbeat;
- frozen-child watchdog;
- startup/empty/absolute TTLs;
- monotonic `IN_MATCH` state after first admission;
- authoritative match result;
- result process reaping.

## Firewall

UFW and the cloud provider firewall/NSG/Security List must both allow the required public ports.

Oracle Cloud minimum external rules:

```text
TCP 80
TCP 443
UDP 24560
UDP 24600-24749
```

Only expose TCP 24561 if the external legacy directory path is actually needed. Never expose TCP 24562.

Opening UFW alone is insufficient if Oracle's VCN/subnet Security List/NSG blocks the same traffic.

## Validation/update commands

Validation without changing the last successful deploy state:

```bash
sudo /opt/nexora-deadfall/deploy/vps/update.sh --tests-only
```

Full rebuild/deploy:

```bash
sudo /opt/nexora-deadfall/deploy/vps/update.sh --force
```

Normal managed update:

```bash
nexora-deadfall update
```

Useful commands:

```bash
nexora-deadfall status
nexora-deadfall build-app
nexora-deadfall build-web
nexora-deadfall build-all
nexora-deadfall logs 200
nexora-deadfall auth
nexora-deadfall https
nexora-deadfall test-models
```

## Expected non-blocking ADB message

A server with no Android device attached may print:

```text
cannot connect to daemon at tcp:5037: Connection refused
```

This is not a failed gate by itself. Evaluate actual Godot/Gradle/export/signing/API markers.

## Services

```bash
sudo systemctl status nexora-deadfall
sudo systemctl status nexora-deadfall-download
sudo systemctl status nginx
```

## Important managed paths

```text
/opt/nexora-deadfall                    repository checkout
/var/lib/nexora-deadfall               persistent runtime/build/match state
/etc/nexora-deadfall                   configuration + signing secrets
/var/www/nexora-deadfall               public APK/release metadata
/var/log/nexora-deadfall               logs
/usr/local/bin/nexora-deadfall         administration command
```

## Portal deployment

Current web source:

```text
web/download-site
```

The existing portal reads current `release.json`. The next web phase will add durable release history, hamburger navigation and version-detail pages. That work must remain independently deployable as a web-only update when no Android/server runtime changed.

See `docs/DOWNLOAD_PORTAL_PLAN.md`.

## Production rule

Never claim a runtime version is deployed merely because source changed. A runtime release is considered deployed only after its intended validation/build/publication/health-check path completes. Documentation-only commits do not require `--force`.
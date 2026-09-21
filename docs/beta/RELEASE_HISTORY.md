# NEXORA: DEADFALL — Closed Beta Release History

Last updated: 2026-09-21.

This file is the human-readable release-history index used by maintainers and as the planning source for the future public version-history page.

## Rules

- Never invent release details that cannot be verified from source, release notes, deployment records or Git history.
- Keep one detailed Markdown release note per intentionally published/candidate version when possible.
- The public portal may later consume a structured release-history dataset, but this Markdown history remains useful for maintainers.
- A source/documentation commit is not automatically a new game version.
- A version becomes a deployed runtime version only after the intended build/deployment gate completes.

## Current source candidate

### 0.9.0-beta.6 — versionCode 900006

Status: source candidate on `agent/city-simulation-upgrade`, PR #16.
No signed APK or production deployment is claimed by this entry.

- 192 × 192 m city, fifteen enterable buildings, natural ground/asphalt,
  vegetation, fourteen wrecks and four client-side fires.
- Corrected zombie navigation height, persistent pursuit, curb stepping and
  target disposal on disconnect.
- Dedicated simulation/collision/AI/networking without presentation nodes.
- Independent ENet game RTT, reusable HTTP lobby probe and process metrics.
- VALERIA replaces the other active operator design; DANTE remains.
- Content version 2; server and all testers must update together.
- Portal preserves the previously published APK while exporting the new one.

Validation and recovery details: `../HANDOFF_CITY_SIMULATION.md`.

## Previous deployed release

### 0.9.0-beta.5 — versionCode 900005

Status: **deployed to the production Closed Beta distribution path; physical multi-device acceptance still pending**.

Runtime deployment anchor:

```text
f402f1696c0438447d76236122a5d82101a94cc0
```

Focus: dedicated-match lifecycle, recovery and cleanup.

Major additions/changes:

- ticket-scoped reconnect tied to the same admitted guest/entity;
- Android reconnect window 42 s / max 10 attempts;
- authoritative state restoration;
- dedicated child heartbeat every 2 s;
- parent frozen-process watchdog;
- startup/empty/runtime TTLs;
- terminal child reaping;
- monotonic `READY -> IN_MATCH` lifecycle after first admission;
- authoritative victory/defeat/aborted results;
- result screen and squad return to lobby;
- safe aggregate lifecycle metrics;
- real Linux child-process/ticket reconnect regression test.

Production validation completed:

- full VPS gate sequence;
- Android Release build;
- APK Signature Scheme v2 verification;
- exactly one signer;
- stable APK publication;
- localhost API validation;
- HTTPS API validation.

Still pending before calling beta.5 fully accepted:

- physical Solo test;
- Duo public-Internet test;
- deliberate disconnect/reconnect test;
- result-to-lobby test;
- 3-player test;
- 4-player test;
- compatibility/performance/thermal observations.

Detailed notes: `RELEASE_NOTES_0.9.0-beta.5.md`.

---

### 0.9.0-beta.4 — versionCode 900004

Status: **successfully built/deployed in the previous production cycle; superseded by beta.5**.

Focus: presentation, imported models/animations and Android performance tiers.

Major additions/changes:

- Lobby 2.0 presentation;
- central 3D operator preview/turntable;
- model normalization;
- shared animation driver;
- safe generic animation fallback;
- verified Quaternius semantic mappings;
- headless presentation-model suppression;
- render scale/LOD/MSAA/FPS tier tuning;
- zombie visual-distance culling;
- beta.4 presentation/mobile regression gate;
- Android generated-template Manifest sanitizer.

Carried gameplay work included rifle/pistol/machete, finite ammo, drops/pickups, sprint toggle, HP/ammo HUD, day/night, loading/recovery and private match tickets.

Detailed notes: `RELEASE_NOTES_0.9.0-beta.4.md`.

---

### 0.9.0-beta.3 — versionCode 900003

Status: **historical intermediate Closed Beta; superseded**.

The repository contains verified production/gate evidence for beta.3, but no dedicated `RELEASE_NOTES_0.9.0-beta.3.md` currently exists. Before publishing a public detailed beta.3 history page, reconstruct the exact changelog from Git/deployment history rather than guessing.

Verified broad scope carried into beta.4 included:

- Lobby -> matchmaking -> dedicated match loading/recovery;
- authoritative 1-4 player matchmaking/party isolation;
- private per-member match tickets;
- MTU-safe FastLZ transport;
- combat/loadout/ammo/pickup hardening;
- mobile gameplay/HUD improvements;
- day/night and model-integration foundations.

Treat this as an index summary only until exact commit-by-commit release notes are reconstructed.

---

### 0.9.0-beta.2

Status: **historical intermediate Closed Beta; superseded**.

No dedicated release-note file currently exists in the tracked documentation. Reconstruct exact changes from Git history before showing detailed public notes. Do not infer or fabricate a release list from later versions.

---

### 0.9.0-beta.1

Status: **first documented Closed Beta candidate; superseded**.

Focus:

- Android FPS/TPS movement and touch controls;
- NXR-4 rifle and authoritative damage/body zones;
- Walker/Runner/Crawler/Tank/Screamer Horde gameplay;
- gore/dismemberment budgets;
- offline Horde;
- authoritative 1-4 player Squad with DOWNED/revive/reconnect foundation;
- Campaign Mission 01/02;
- checkpoint recovery;
- Closed Beta compatibility, abuse guards, diagnostics and hardened saves.

Detailed notes: `RELEASE_NOTES_0.9.0-beta.1.md`.

## Future release-record standard

For every new intentionally published version, record at minimum:

```text
version
versionCode
channel
publication date/time
runtime deployment commit
summary
added
changed
fixed
known limitations
network/protocol/content compatibility
Android target
APK size
SHA-256
signature verification result
VPS gates result
physical acceptance status
```

## Structured portal registry

The durable source record for the public portal is tracked at:

`web/download-site/src/data/releases.json`

The VPS build automation validates that schema, merges the verified current `release.json` fields without discarding the tracked history, and publishes:

`/var/www/nexora-deadfall/releases.json`

The portal does not scrape this Markdown file at runtime. Beta.2 and beta.3 remain intentionally absent from the public detailed registry until their exact notes are reconstructed.

## Portal integration

The future download portal must expose a user-friendly subset of this history through a hamburger menu and version pages. See:

`docs/DOWNLOAD_PORTAL_PLAN.md`

The public portal history should distinguish:

- Current
- Superseded
- Withdrawn (if a future build is removed for a critical issue)

A withdrawn build should remain in historical notes while its binary download can be disabled.
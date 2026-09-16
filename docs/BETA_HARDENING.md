# Closed Beta hardening

Phase 9 prepares NEXORA: DEADFALL for controlled external Android testing. It deliberately hardens the existing Phase 1–8 gameplay rather than adding another major gameplay system.

## Build identity and compatibility

The beta build identity lives in `src/release/BuildInfo.gd`:

- App version: `0.9.0-beta.1`
- Version code: `900001`
- Channel: `closed_beta`
- Network protocol: `2`
- Content version: `1`
- Target Android API: `36`
- Maximum gameplay peers: `4`

The room directory advertises build/content compatibility metadata. The hardened gameplay session performs a reliable build hello before the normal room join and refuses protocol, content or supported-version mismatches before a player entity is created.

## Network abuse boundary

`ClosedBetaNetworkSession.gd` subclasses the proven Squad session rather than rewriting prediction or replication. It adds:

- build handshake before join;
- payload-shape and maximum-size validation;
- command/fire/reload/restart rate limits;
- strike accumulation and sustained-abuse disconnect;
- display-name/resume-token bounds;
- security breadcrumbs in the privacy-safe local beta runtime.

Clients still never authoritatively provide health, damage, hit results, revive completion, campaign completion or server transforms.

## Runtime/crash diagnostics

`BetaRuntime` is an autoload that records a bounded local event ring and a session marker. A session starts as `clean_shutdown=false` and is marked clean during normal exit. On the next launch, an unclean prior session creates `user://beta_last_crash_report.json` with the previous build/device snapshot and recent privacy-filtered breadcrumbs.

This detects crash/kill/unclean-exit conditions and gives closed-beta testers a reproducible local report. It is not a native stack-trace SDK and does not upload diagnostics automatically. Android `logcat`/ANR/native crash data can be collected with `scripts/beta/collect_android_report.sh` when investigating a device failure.

## Device compatibility

The runtime records OS/model, processor count, memory, renderer/GPU details and window dimensions when available. It also returns a recommended quality tier but does not silently change the player's selected quality.

The physical-device matrix remains an execution gate because hardware coverage cannot be manufactured by CI.

## Persistence

Campaign saves are now schema version 2. The primary save contains a SHA-256 protected JSON payload, writes through a temporary file, and preserves the previous valid save as `.bak`. Load falls back to the valid backup when the primary file is truncated/corrupt and migrates Phase 8 version-1 saves.

## Release pipeline

`.github/workflows/closed-beta-release.yml` creates:

- signed ARM64 Android App Bundle for Play closed testing;
- signed ARM64 APK for direct controlled testing;
- SHA-256 checksum file;
- machine-readable release manifest.

The upload keystore is never committed. The workflow requires these GitHub Secrets:

- `DEADFALL_ANDROID_KEYSTORE_B64`
- `DEADFALL_ANDROID_KEYSTORE_ALIAS`
- `DEADFALL_ANDROID_KEYSTORE_PASSWORD`

The same upload key must be retained between releases.

## Validation gates

Phase 9 adds `scripts/ci/beta_hardening_smoke.gd` and keeps every earlier smoke/integration gate. Final closed-beta readiness still requires current-head CI, signed export, and representative physical Android testing.

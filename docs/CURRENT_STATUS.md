# NEXORA: DEADFALL — Current Status

Last updated: 2026-09-22.

## Current delivery

- Repository: `Gh0stDeveloper/NEXORA-DEADFALL`; VPS updater tracks `main`.
- Base main: `d1616d34e9f2a48e0dfd9285e75720aff826044d`, after authorized merge of PR #17.
- Development: `agent/android-playtest-beta7`.
- Source delivery: **0.9.0-beta.7 / versionCode 900007**; merge authorized
  by the owner on 2026-09-22 after local verification.
- Godot 4.6.3; Android ARM64, target API 36; up to four players.
- Network protocol 2, map/content version 2. Minimum client and server: 900007.
- Recovery/phase checklist: `HANDOFF_ANDROID_PLAYTEST.md`.

The owner tested beta.6 on Android and confirmed improved city/gameplay and
roughly 100–120 ms match RTT, compared with earlier 800–900 ms. This is owner
feedback, not a new local WAN benchmark. The deployed APK SHA was not supplied.

PR #17 fixed the beta.5-to-beta.6 release-history transition and was merged at
the owner's request. `scripts/build/build_download_site.sh` must retain
`--keep-published-version`; the final Android publisher remains strict. Its
regression executes the real production callers, including interrupted retries.

## Beta.7 changes

- Original silhouette HUD: movement/sprint left, direct rifle/pistol/machete
  slots and ammunition top right, combat/stance controls right, HP at bottom.
- Sprint is a forward movement toggle. Backward input, stance, aiming, menus
  and backgrounding stop it. Existing HUD layouts remain saved; reset in the
  HUD editor applies the new defaults.
- Real ENet match ping is visible during online play; stale samples show
  **999 ms · SIN CONEXIÓN**. No fake ping is shown in Solo or over loading.
- SALIR opens confirmation, closes the old transport and returns to the lobby.
  Abandoning removes only that party member; teammates keep their active match.
  Late party replies cannot send the departing player back into the old match.
- Ammo cartridges and green-marked medical kits replace the generic green box.
  Medical kits restore up to 25 HP, without over-healing or reviving a downed
  player. Collection rechecks overlap and remains server-authoritative.
- Fresh account creation and missing-server-account recovery retain the local
  identity. Login controls use deferred cleanup; Android Back does not quit.
- A branded mandatory update check runs before login/play and on frontend
  resume. A newer server version blocks entry even inside an older compatibility
  range. Failed verification offers retry and blocks play, including Solo.
- The city, VALERIA/DANTE, AI/navigation and presentation-free dedicated server
  remain in place. Pickup meshes and labels are client-only.

## Validation / delivery limits

Work is tracked and committed by phases in `HANDOFF_ANDROID_PLAYTEST.md`.
Local Godot compile, account/control/pickup/update, rendered UI and multiplayer
checks exercise the actual engine. See the handoff for the final completed gates.

This source delivery is not a signed Android artifact. Build with the existing
VPS signing identity, install over the existing APK, then verify touch behavior,
fresh account creation, update blocking, drops, Duo/Squad exit and reconnection
on the testers' actual phones. Do not clear application data to update.

The new mandatory-update interface becomes available after installing beta.7;
older installed APKs cannot acquire this UI from a server-only update.

## Production layout

- Main runtime checkout: `/opt/nexora-deadfall`.
- Persistent data: `/var/lib/nexora-deadfall`.
- Configuration/signing: `/etc/nexora-deadfall`.
- Public portal: `/var/www/nexora-deadfall`.
- Control API localhost TCP 24562, published through HTTPS/Nginx.
- Dedicated matches: UDP 24600–24749; base legacy UDP 24560.
- Stable download: `/downloads/NEXORA-DEADFALL-latest.apk`.
- Update command after the delivery is merged: `sudo nexora-deadfall update --force`.

`cannot connect to daemon at tcp:5037` concerns ADB when no Android device is
attached to the VPS; it is not the release-history failure or a compile gate.

## Continuing this work

Read this file and `HANDOFF_ANDROID_PLAYTEST.md` first. Older handoffs and
`beta/RELEASE_HISTORY.md` retain historical context. Never publish the synthetic
local Git ancestry: base commits/trees on the actual remote branch. Preserve the
`vendor/Objetos3D` gitlink and asset symlinks. Do not exclude `scripts/build/`
when collecting source changes. Keep signing keys and profiles out of commits.

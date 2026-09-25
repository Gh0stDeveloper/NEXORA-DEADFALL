# NEXORA: DEADFALL — Current Status

Last updated: 2026-09-25.

## Current delivery

- Repository: `Gh0stDeveloper/NEXORA-DEADFALL`; VPS updater tracks `main`.
- Base main: `5f08a0c01ed98387730523e34b5ec714dbcce0a7` (PR #18 / beta.7).
- Development: `agent/social-modes-beta8`.
- Source candidate: **0.9.0-beta.8 / versionCode 900008**.
- Godot 4.6.3, Android ARM64 / API 36, maximum four players.
- Protocol 2, map/content version 2. Minimum client and server: 900008.
- Recovery/phase checklist: `HANDOFF_SOCIAL_MODES.md`.

## Beta.8 behavior

- Hold the fire button and drag to move the camera while firing. The same finger
  retains its action outside the circle; other fingers can move the joystick.
- An empty magazine reloads automatically when reserve exists. Otherwise select
  a loaded firearm, then one with reserve, and finally melee. The server owns
  ammunition; touch fire continues with the pistol at its configured cadence.
- Profile: operator, username, copyable public ID and last-100-match statistics.
- Friends: current status, name/ID search, add, accept/reject requests and chat.
- History: actual dedicated-server results persisted per account. Old releases
  have no retroactive history. An unfinished match is saved when it ends.
- Six illustrated mode cards: campaign, ten-wave assault, endless survival,
  PvP FFA, duo duel and private duel within the existing party.
- Co-op fills compatible queued parties of the same mode/mission/formation;
  existing groups stay together. Launch after eight seconds even when incomplete.
- PvP fits at most four players: all against all, or two teams of up to two.
  A lone duo member can join another queued team or play 1v1; no invented rivals.
  A search without a real opponent returns after 30 seconds and can be retried.
- PvP has friendly-damage blocking, three-second respawn, two-second spawn
  protection, ten-kill target and five-minute limit. Ties are draws.
- The mode supervisor keeps only identity/team/stats logic and collision
  hitboxes. Models, visual effects, audio and UI remain client-only.
- Lobby formation updates preserve teammates; older poll replies cannot revert
  an in-flight formation change. Only the leader selects/starts the match.

Beta.7's match ping, exit, health/ammunition drops, persistent HUD layout, new
account recovery and mandatory-update screen remain. The beta.6 city and
VALERIA/DANTE remain. The owner reported 100–120 ms WAN RTT on beta.6 Android;
that is owner feedback, not a measurement of this build.

## Validation and release limits

See `HANDOFF_SOCIAL_MODES.md` for the completed gates and remaining checks.
Local tests run the actual Godot engine, rendered screens, HTTP services and ENet
clients. They do not constitute a signed APK or physical Android acceptance.

CI model staging requires `DEADFALL_MODELS_TOKEN` with read access to private
`Gh0stDeveloper/Objetos3D`. Missing CI credentials must not be worked around by
removing asset-validation gates. The existing VPS has its vendored model checkout.

Update server and all client APKs together. Build with the existing signing key
and install over the existing APK to preserve account/HUD data. Do not clear data.

PR #17 fixed release-history transitions: `scripts/build/build_download_site.sh`
must retain `--keep-published-version` while the Android exporter runs. Final APK
publication remains strict. The old APK/catalog remain available on interrupted
builds; source metadata does not pretend that a new binary is already published.

## Production layout

- Runtime checkout: `/opt/nexora-deadfall`.
- Persistent data: `/var/lib/nexora-deadfall`.
- Configuration/signing: `/etc/nexora-deadfall`.
- Portal: `/var/www/nexora-deadfall`.
- Control API: localhost TCP 24562 via HTTPS/Nginx.
- Dedicated matches: UDP 24600–24749; legacy base UDP 24560.
- Stable APK: `/downloads/NEXORA-DEADFALL-latest.apk`.
- After merge: `sudo nexora-deadfall update --force`.

No VPS shell or physical testers' phones are connected to this workspace.

## Continuing

Read this and `HANDOFF_SOCIAL_MODES.md`. Older handoffs retain historical context.
Never publish the synthetic local Git ancestry. Use actual remote parents/trees,
preserve `vendor/Objetos3D` gitlink and GLB symlinks, and keep `scripts/build/` when
collecting changes. No keys, account state or admission tickets belong in commits.

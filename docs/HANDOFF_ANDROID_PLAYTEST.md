# Android playtest follow-up — beta.7

Base: main `d1616d34e9f2a48e0dfd9285e75720aff826044d` (PR #17 merged).
The owner tested beta.6 on Android and confirmed improved city/gameplay and
approximately 100–120 ms gameplay RTT, compared with the former 800–900 ms.
These are owner observations, not a new local WAN measurement.

Development branch: `agent/android-playtest-beta7`. Do not publish the synthetic
local Git ancestry; create commits with the real remote parent/tree. Explicitly
include production files in `scripts/build/`. Preserve vendor gitlink and symlinks.

## Phases

- [ ] A: HUD inspired by the supplied layout: joystick left, sprint above it,
  weapon silhouettes and direct slots at top right, fire/jump/stances on right,
  HP at bottom, editable positions/scale/opacity preserved.
- [ ] B: Match-only ENet ping with stale/disconnected 999 ms state; accessible
  leave-match confirmation and clean lobby return, including Solo and reconnect.
- [ ] C: Recognizable ammunition and medical drops, authoritative automatic
  collection, usable from every weapon, replication and no server presentation.
- [ ] D: Fresh/missing-account recovery without closing the application; safe UI
  transitions and Android Back behavior. Test real HTTP registration.
- [ ] E: Branded mandatory-update gate before playing, recheck on resume/start,
  explicit retry on unavailable service and download access; beta.7 compatibility.
- [ ] F: Strict compile, targeted regressions, rendered HUD/account/update flow,
  network validation, release metadata and publication checkpoints.

Keep existing city, movement authority and network optimizations. No signed APK
or physical acceptance is claimed until built on the owner's VPS and retested.

## Recovery

Read this file, CURRENT_STATUS.md and the branch commits. Local runtime is Godot
4.6.3. Use isolated XDG_DATA_HOME for account/HTTP/render fixtures. Main's release
transition fix from PR #17 must remain. The user-supplied HUD is a layout reference;
create original icons and do not import assets from the reference game.

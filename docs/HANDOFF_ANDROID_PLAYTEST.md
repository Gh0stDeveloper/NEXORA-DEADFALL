# Android playtest follow-up — beta.7

Base: main `d1616d34e9f2a48e0dfd9285e75720aff826044d` (PR #17 merged).
The owner tested beta.6 on Android and confirmed improved city/gameplay and
approximately 100–120 ms gameplay RTT, compared with the former 800–900 ms.
These are owner observations, not a new local WAN measurement.

Development branch: `agent/android-playtest-beta7`. Do not publish the synthetic
local Git ancestry; create commits with the real remote parent/tree. Explicitly
include production files in `scripts/build/`. Preserve vendor gitlink and symlinks.

## Phases

- [x] A: HUD inspired by the supplied layout: joystick left, sprint above it,
  weapon silhouettes and direct slots at top right, fire/jump/stances on right,
  HP at bottom, editable positions/scale/opacity preserved.
- [x] B: Match-only ENet ping with stale/disconnected 999 ms state; accessible
  leave-match confirmation and clean lobby return, including Solo and reconnect.
- [x] C: Recognizable ammunition and medical drops, authoritative automatic
  collection, usable from every weapon, replication and no server presentation.
- [x] D: Fresh/missing-account recovery without closing the application; safe UI
  transitions and Android Back behavior. Test real HTTP registration.
- [x] E: Branded mandatory-update gate before playing, recheck on resume/start,
  explicit retry on unavailable service and download access; beta.7 compatibility.
- [x] F: Strict compile, targeted regressions, rendered HUD/account/update flow,
  network validation, release metadata and publication checkpoints.

Keep existing city, movement authority and network optimizations. No signed APK
or physical acceptance is claimed until built on the owner's VPS and retested.

## Recovery

Read this file, CURRENT_STATUS.md and the branch commits. Local runtime is Godot
4.6.3. Use isolated XDG_DATA_HOME for account/HTTP/render fixtures. Main's release
transition fix from PR #17 must remain. The user-supplied HUD is a layout reference;
create original icons and do not import assets from the reference game.

## Implementation checkpoint

Beta.7 source: 900007, protocol 2, content version 2. Server and clients must
update together. A–F are implemented and locally verified. The owner authorized merging this
delivery into main on 2026-09-22. Signed APK export and physical Android acceptance
remain deployment/device checks, not completed local claims.

Already passed locally: strict gameplay compilation and its child regressions,
including Android controls/health/ammo/update logic; isolated real HTTP account
creation, failed transport/retry and missing-account recovery; rendered HUD,
update screen, leave confirmation and return to lobby; beta hardening and VPS
installer/release-transition checks. Four-client city load and updated Phase 11
integration also passed, including both pickup types and match abandonment.

The rendered test uses fixture ping values for screenshots; those pictures are
not a WAN latency measurement. Existing custom HUD positions are retained:
use Settings → HUD editor → Reset to apply the new default layout.

## Final local verification — 2026-09-22

- Godot 4.6.3 editor import and strict compilation, including actual runtime
  controls/pickup/update regression and existing login/gameplay/lifecycle tests.
- Real local HTTP fresh-account registration, connection failure/retry, missing
  server record recovery, saved identity and Android Back routing.
- Rendered 1280×720 boot, lobby, formation, controls, weapon slots, auto-run,
  mandatory update, 999 ping fixture, exit confirmation and lobby return.
  No script errors or leaked audio resources in the completed rendered run.
- Medical collection after damage while already overlapping; max-health clamp,
  full active pistol with empty rifle, replica deletion and no headless visuals.
- Social HTTP leave route preserves the teammate and transfers leadership;
  delayed leave/party replies cannot replace a newly joined party.
- Four actual ENet clients for 20 samples each: 23 replicated zombies,
  22–23 moving per client, p50 16–17 ms, p95 16–17 ms, maximum 18 ms.
  Dedicated presentation nodes: 0; approximately 16.04% of one CPU core,
  peak RSS 157.04 MiB, steady physics 60 Hz. This is local loopback only.
- Both ammunition and medical pickup kinds reached every ENet client.
- Project, combat, Horde, networking, Squad and Campaign regression gates passed.
- Standalone Next.js build/routes and the real beta.6 → beta.7 release-publication
  transition passed, including preservation/retry of the previously published APK.
- The load harness drains each child process's stdout before inspecting the
  terminal result, preventing incomplete buffered logs from failing the gate.

Commands: `godot --headless --path . --script scripts/ci/gameplay_compile_smoke.gd`,
`phase11_smoke.gd`, `beta_hardening_smoke.gd`, `python3 scripts/ci/match_load_smoke.py`,
and `xvfb-run -a bash scripts/ci/presentation_runtime_smoke.sh` (isolated profile).
See `.github/workflows/ci.yml` for the full pipeline and retained captures.

## Deploy and phone acceptance

After merge, run `sudo nexora-deadfall update --force`. It builds both the portal
and signed APK using the existing signing identity. Install the APK over beta.6
on all tester phones. Verify fresh account creation, multi-touch controls,
auto-run stop/resume, ammo/health pickups, in-match ping and one teammate leaving
while the others continue. Older beta.6 APKs cannot display the new beta.7 update UI.

Do not clear application data or regenerate the signing key. No new Android
native-crash log was supplied: account recovery and Back handling are tested fixes,
not a claim to have diagnosed an unseen native Android stack trace.

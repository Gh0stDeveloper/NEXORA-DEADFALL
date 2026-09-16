# Tactical presentation phase — 2026-09-16

> The owner subsequently authorized merging PR #1 into main. The Draft-only
> instruction in this historical delivery is superseded; see
> [HANDOFF_PORTAL_MAIN.md](HANDOFF_PORTAL_MAIN.md).

The requested boot/account/lobby/operator/weapon/audio phase is implemented and
locally validated on `agent/bootstrap-deadfall`. Keep PR #1 open and Draft.
This supersedes the incomplete recovery checkpoint of 2026-09-14. It is a source
delivery, not a new Android release or a production deployment.

## Delivered behavior

- A lightweight boot scene displays the new artwork before threaded main-scene
  loading. Loading reflects real stages; retries reset progress.
- Account entry displays registration/challenge/verification states, rejects
  malformed or expired sessions, retains names on failure and bounds missing-user
  recovery. The lobby opens only after a verified session.
- Amber/cyan tactical lobby with original hangar art, Rajdhani typography, icons,
  one shared 3D formation stage, Solo/Duo/Squad vacancies, identity and team panels.
  Friends, chat, squad codes, leader controls and matchmaking retain their server
  checks. Operator selection, rotating arsenal and settings are integrated.
- MARA/DANTE use the supplied skinned characters, fitted tactical equipment,
  procedural locomotion/poses and two-bone weapon-grip IK. Normalization measures
  skinned vertices, avoiding incorrect source-unit scaling and floating feet.
- Zombie variants use verified Quaternius locomotion/attack clips with persistent
  limb removal. Damage does not recreate the rig. Native geometry remains a
  missing-model fallback; authoritative hitboxes and damage remain unchanged.
- Detailed rifle, pistol and machete geometry, aligned first-person hands,
  recoil/muzzle flash and weapon inspection. View models are built after the
  camera is ready, fixing invisible weapons during normal scene startup.
- Thirteen original effects plus original music and ambience loops. Master,
  Music, SFX, UI and Ambience controls persist, with a limiter, bounded spatial
  voice pool, distance/throttle rules, fades and focus pause/resume.
- Hidden lobby stages stop rendering/animation. Geometry/materials are cached
  and batched, zombie animation is budgeted, and dedicated/headless processes
  skip character/audio presentation.

Primary files: `src/main/Boot.gd`, `src/login/LoginGate.gd`,
`src/lobby/LobbyController.gd`, `src/lobby/TacticalStage.gd`,
`src/assets/SkinnedOperatorRig.gd`, `src/assets/SkinnedZombieRig.gd`,
`src/assets/ModelNormalizer.gd`, `src/assets/PresentationMesh.gd`,
`src/assets/ProceduralWeaponModels.gd`, `src/audio/AudioDirector.gd`.

`USE_EXTERNAL_MODELS := false` in legacy presenters selects the new character
factory. That factory now uses skinned source models with custom rig behavior;
it does not mean that no GLBs are loaded. The older direct-import path remains
available for compatibility.

## Validation completed locally

Godot 4.6.3-stable, Linux, software OpenGL rendering at 1280 × 720:

- All 16 existing gates passed: strict gameplay compile and its child suites,
  project, combat, zombie, gore, Horde, networking, Squad, Campaign, beta hardening,
  Phase 11, Android template patch, VPS installer contract, two-peer Duo,
  four-peer Squad and four-peer Campaign integration.
- New asset regression checks all four GLB bounds, floor placement, operator
  weapon grips/prone/locomotion, weapon surface budgets and first-person hands,
  five zombie variants with persistent gore, and all audio assets.
- Rendered runtime regression passed the actual Boot → Login → connection failure
  → retry → local HTTP guest registration → verified lobby → Duo/Squad formation
  → arsenal/operators/settings → Solo Campaign → all three visible weapons →
  firing sequence and audio focus transitions. It checks persisted volume,
  selected-character synchronization and hidden-stage processing.
- Captures and logs are generated under `build/presentation-smoke/` and uploaded
  by the CI presentation step. Review samples are in `docs/media/`.
- The pre-existing tests now load gameplay scripts after autoload initialization,
  so standalone test invocation no longer fails before exercising its assertions.

Reproduce after initializing/staging the required pinned models:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script scripts/ci/gameplay_compile_smoke.gd
godot --headless --path . --script scripts/ci/phase11_smoke.gd
bash scripts/ci/duo_integration.sh
bash scripts/ci/squad_integration.sh
bash scripts/ci/campaign_integration.sh
xvfb-run -a bash scripts/ci/presentation_runtime_smoke.sh
```

The rendered test uses a temporary isolated profile and a local control API on
port 24862. It does not use a player's account or the production API. Its dummy
audio driver verifies routing/playback state; it is not a headphone listening
test. Boot timings in this fixture are cached desktop measurements, not Android
performance claims. The fixture can show a disconnected network badge because
the production telemetry endpoint is independent of its local account API.

## Remaining release gates and scope limits

- Android SDK/export templates are unavailable in this execution environment;
  the attempted official template download returned HTTP 403. No new APK was
  exported here. Run the existing Android/VPS pipeline and physical Solo → Duo
  → 3/4-player acceptance, including reconnect/results, before releasing.
- Measure actual device FPS, memory, thermals, touch usability, audio balance
  and pause/resume. Local tests do not certify mobile performance.
- Separate authored player animation sets and verified zombie Hurt/Death clips
  remain future art work. Current procedural poses are not a full authored set.
  Environment art/level dressing remains the existing vertical slice.
- Preserve the per-model licensing gate in `THIRD_PARTY_3D_ASSETS.md`; no new
  license is inferred from the user-supplied model repository.
- Remote Actions results must be checked on the published commit. Previous
  runs had no runner and zero steps, so they did not execute source tests.

The model gitlink stays at `28ea7a10a18fbe05a91fb3d920678991fff4afef`.
Version remains `0.9.0-beta.5 / 900005`, protocol 2, content version 1, API 36.
Last verified production deployment remains
`f402f1696c0438447d76236122a5d82101a94cc0`. Signing identity, production services
and release history are unchanged by this source delivery.

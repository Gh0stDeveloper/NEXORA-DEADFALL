# Quality gates

Every pull request should satisfy the gates relevant to its scope.

## Gate 1 — Repository integrity

- Godot project imports headlessly.
- Main scene loads and instantiates.
- No missing required bootstrap scripts.
- Shell scripts pass `bash -n`.

## Gate 2 — Server packaging

- Dedicated server Docker image builds on Ubuntu runner.
- Server bootstrap can parse `--server` and port arguments.
- Runtime dependencies remain explicit.

## Gate 3 — Android packaging

- Android debug export completes for ARM64.
- Emulator APK installs and launches when the runtime workflow is available.
- Android runtime markers validate landscape/safe-area/touch input and gore budget initialization.
- Release signing material is never stored in the repository.

## Gate 4 — Gameplay tests

Pure simulation and integration smoke suites are mandatory as their systems appear:

- `smoke.gd` — project/scene contracts.
- `combat_smoke.gd` — damage, body zones, cadence, ammo and reload.
- `zombie_smoke.gd` — AI perception/state/authority/melee/death.
- `gore_smoke.gd` — bounded effect budgets, prepared limb contract, dismemberment, crawler, arm penalties and head-destruction death.

Scene/integration smoke tests complement but do not replace deterministic simulation tests.

## Gate 5 — Performance

Each major gameplay milestone must be profiled on at least one low/mid device and one higher-end device. Gore profiling must record active/peak pooled limbs and decals plus configured tier budgets from `DEADFALL_GORE_STATS`. A feature that works only on desktop is not considered complete.

## Gate 6 — Multiplayer correctness

Before closed co-op beta: latency simulation, disconnect/reconnect, invalid RPC fuzzing, duplicate/out-of-order input handling, four-player soak testing and server memory/CPU monitoring are required.

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
- APK is uploaded as a CI artifact.
- Release signing material is never stored in the repository.

## Gate 4 — Gameplay tests

As systems appear, add automated tests for pure simulation logic first: damage calculations, wave formulas, inventory rules and protocol serialization. Scene/integration smoke tests complement but do not replace those tests.

## Gate 5 — Performance

Each major gameplay milestone must be profiled on at least one low/mid device and one higher-end device. A feature that works only on desktop is not considered complete.

## Gate 6 — Multiplayer correctness

Before closed co-op beta: latency simulation, disconnect/reconnect, invalid RPC fuzzing, duplicate/out-of-order input handling, four-player soak testing and server memory/CPU monitoring are required.

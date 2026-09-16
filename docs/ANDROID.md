# Android build and performance plan

## Baseline

- Godot 4.6.3 stable.
- Landscape gameplay locked through the handheld orientation project setting.
- ARM64 is the primary architecture.
- Mobile renderer is the default project renderer.
- Target entry hardware: approximately 2–3 GB RAM, subject to real-device profiling.

## Phase 1 controls

The first playable controller supports both desktop development input and Android touch input.

Desktop debug bindings:

- W/A/S/D: movement.
- Shift: sprint.
- Space: jump.
- C: crouch toggle.
- Z: prone toggle.
- V: camera cycle.
- Mouse: look.
- Escape: release/capture mouse.

Android controls:

- Left virtual joystick: movement.
- Right touch region: camera/look.
- Dedicated RUN, JUMP, CROUCH, PRONE and CAM buttons.
- HUD layout is placed inside a safe-area-aware root for display cutouts/notches.

Touch-look uses unscaled screen-relative drag motion so sensitivity is not unintentionally altered by viewport stretching. The project uses `canvas_items` with `expand` to better cover elongated phone aspect ratios.

## Build strategy

`export_presets.cfg` contains an unsigned Android debug preset for CI compilation checks. Production Play builds will use a separate signed release preset and credentials injected from GitHub Actions secrets; keystores must never be committed.

Google Play release packaging and signing will be finalized before closed testing. Release credentials are expected to live only in encrypted repository/environment secrets.

## Performance budgets

Performance work starts in the vertical slice, not after content completion.

Measure at minimum:

- CPU frame time.
- GPU frame time.
- draw calls.
- visible triangles.
- texture memory.
- total process RAM.
- active physics bodies.
- active navigation agents.
- particles/decals/limbs in scene.
- thermal throttling over sustained sessions.

## Device tiers

Smooth, Standard, Ultra and Ultra HD are user-facing profiles. Automatic recommendation is allowed, but manual override remains available.

## Mobile-specific rules

- Pool high-churn effects.
- Limit dynamic shadow casters by distance and importance.
- Prefer baked/static environment lighting where practical.
- LOD environment and enemy meshes.
- Keep material/shader variants under control.
- Budget transparent overdraw, especially blood particles.
- Use safe areas for display cutouts.
- Keep touch targets comfortably usable across DPI ranges.

## CI

The Android workflow downloads the pinned Godot binary and export templates, configures JDK 17 and uses the runner Android SDK. It compiles an ARM64 debug APK for every relevant pull request. Artifact upload is best-effort while the GitHub account artifact quota is constrained; compilation itself remains a required quality gate.

# Android build and performance plan

## Baseline

- Godot 4.6.3 stable.
- Landscape gameplay.
- ARM64 is the primary architecture.
- Mobile renderer is the default project renderer.
- Target entry hardware: approximately 2–3 GB RAM, subject to real-device profiling.

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

The Android workflow downloads the pinned Godot binary and export templates, configures JDK 17 and uses the runner Android SDK. It produces an APK artifact for build verification; signed release automation is intentionally deferred until release signing secrets are configured.

# NEXORA: DEADFALL — Persistent Project Context

This document is the durable handoff/context file for future development chats. Read it before making architecture, gameplay, UI, networking, build or deployment changes.

## Product identity

- Project: **NEXORA: DEADFALL**
- Developer/brand: **Ghost Developer / Nexora**
- Genre: 3D zombie survival shooter for Android
- Rating target: adults / +18 due to graphic violence, dismemberment and strong language
- Engine: **Godot 4.6.x** using GDScript; C++ through GDExtension is allowed for performance-critical systems
- Primary client: Android ARM64
- Development workflow: the developer frequently works only from a phone plus a VPS, so repository automation, headless validation and reproducible builds are mandatory
- CI/builds: GitHub Actions plus VPS-side headless Godot builds

## Runtime architecture

- Offline and online gameplay must share the same gameplay implementation.
- Offline uses local authority.
- Online uses server authority.
- Dedicated backend is the developer's own Ubuntu VPS running a headless Godot server.
- Multiplayer transport is Godot MultiplayerAPI over ENet/WebSocket where appropriate.
- Supported party sizes: Solo, Duo and Squad (up to 4 players).
- Gameplay modes: Campaign, Normal and infinite Horde/Rounds.
- Do not trust clients for health, damage, hit results, ammo, revive completion, mission progression, Horde decisions or other authoritative state.

## Current production state

- Closed Beta client: `0.9.0-beta.1`.
- Real Android Release APK has been successfully built on the production VPS.
- Gradle release build passed.
- APK signature verification passed with APK Signature Scheme v2 and one signer.
- APK is published at `/var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk`.
- Production portal is served by Next.js behind Nginx.
- HTTP and HTTPS both return 200 for the DEADFALL domain after removal of conflicting Hex Tunnel listeners.
- Production updater completed successfully at Phase 10 head `3f83a1a737adf5a0737bc6393a9dea337600c4db`.
- Physical Android installation/gameplay test has been completed successfully: the game installs, launches and is playable.
- Production signing identity lives under `/etc/nexora-deadfall/signing/` and must never be regenerated during normal updates.

## Current playable prototype

Already present/working:

- Virtual movement joystick.
- Action buttons.
- FPS/TPS camera support.
- Mission HUD.
- Wave / score / kill HUD.
- At least one test zombie in scene.
- Authoritative weapon/damage foundations.
- Zombie AI foundations.
- Gore/dismemberment foundations.
- Horde foundations.
- Campaign vertical slice.
- 1–4 player Squad networking foundations.
- Closed Beta hardening and production deployment.

## Player controls target

Mobile controls must include:

- Virtual movement joystick.
- Run.
- Jump.
- Crouch.
- Prone.
- A single camera-cycle control that switches:
  1. first person;
  2. third-person rear;
  3. third-person front.

HUD buttons should use icons rather than text wherever practical. Avoid emoji in game UI.

## User assets

The developer already has downloaded 3D assets ready for integration, including:

- two distinct playable-character models;
- zombie models.

Additional environment assets are still needed: low-poly walls, houses, abandoned vehicles and urban debris. Vehicle fire should use particles/shaders rather than a static fire mesh.

## Immediate gameplay/UI problems

### HUD overlap

The Mission panel and Wave/Score panel currently overlap in the upper-left area. They must be separated or the upper HUD must be redesigned as one coordinated layout.

### Camera sensitivity

Touch camera sensitivity currently feels too low. Sensitivity must become a persistent user preference with a settings slider, expected range approximately `0.1–1.0`.

Current baseline idea:

```gdscript
@export var look_sensitivity := 0.25

func _input(event):
    if event is InputEventScreenDrag:
        camera_pivot.rotate_y(-event.relative.x * look_sensitivity * 0.01)
        camera_pivot.rotate_x(-event.relative.y * look_sensitivity * 0.01)
        camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -1.2, 1.2)
```

### Night visibility

Night scenes are too dark. Current tuning baseline:

```gdscript
environment.ambient_light_energy = 0.6
environment.tonemap_exposure = 1.3
environment.adjustment_enabled = true
environment.adjustment_brightness = 1.15
```

Target additions:

- subtle moon `DirectionalLight3D`;
- low energy;
- soft shadows;
- equipable camera-mounted `SpotLight3D` flashlight;
- flashlight on/off control as an actual night-survival mechanic.

### Mobile HUD controls

Redesign action buttons as:

- circular;
- semi-transparent;
- icon-based;
- larger and thumb-friendly;
- sufficiently separated;
- obvious pressed-state visual feedback.

### Audio

Audio integration is pending:

- gunshots;
- zombie growls/vocals;
- ambient environment sound;
- background music;
- UI feedback sounds.

## Lobby system target

A pre-match lobby must exist before each online match.

Required behavior:

- Select Solo / Duo / Squad.
- Players can freely join or leave Duo/Squad parties.
- Only the party leader can kick members.
- Only the party leader can start the match.
- Lobby text chat.
- Lobby visually shows the selected character for the local player.
- Duo/Squad lobby also shows selected characters for all party members.
- Lobby must be visually designed, not only functional.

## Guest account target

Full registration is not required yet. Implement persistent guest identities first.

Requirements:

- Server recognizes each guest account by a unique ID.
- Player chooses username.
- Username maximum: 12 characters.
- No emoji in username.
- Username must be unique on the server.
- Guest account persists across app sessions.
- Local account data is stored in a `.dat` file whose payload is readable plain-text JSON.
- Store at least guest ID and password/authentication hash material; never store a plaintext password.
- Server remains authoritative for identity uniqueness and authentication acceptance.

Security note: emulate the persistence/user experience of games such as Free Fire, but do not copy proprietary authentication algorithms. Use standard salted password hashing / verifier patterns suitable for the server architecture.

## Settings target

### In-match settings

Keep this intentionally minimal to avoid disrupting gameplay:

- camera/touch sensitivity only initially.

### Main-menu settings

Full settings panel should include:

- camera/touch sensitivity;
- master game volume;
- music volume;
- HUD editor.

### HUD editor

Every configurable HUD control should support independently:

- free position;
- size/scale;
- visibility;
- opacity.

The edited HUD layout must persist between sessions and support safe reset-to-default.

## Design/engineering constraints

- Android-first UX; targets must be touch-friendly.
- Avoid emoji in production game UI; use icons/assets.
- Prefer scalable layouts over fixed pixel coordinates.
- Persist user preferences through the existing Settings/DataStore-style Godot persistence layer rather than scattering save logic through gameplay scripts.
- Preserve server authority.
- New networking features need abuse/rate-limit validation from the start.
- New gameplay systems should work offline and online without maintaining duplicate logic.
- Heavy CPU-sensitive systems may move to GDExtension only after profiling shows a need.
- VPS fixes must also be reflected in source/deployment automation so clean installations remain reproducible.

## Repository/deployment rules

- Active development branch during this phase: `agent/bootstrap-deadfall`.
- Draft PR #1 remains open until explicitly approved for merge.
- Never merge PR #1 without explicit developer instruction.
- Production update command is `nexora-deadfall update`.
- GitHub Actions should remain part of build/validation even when VPS-side validation is also used.
- Keep keystore secrets out of Git and logs.

## Next development phase

Phase 10 production deployment is functionally proven on a real VPS and physical Android device. The next work should be treated as a gameplay/polish/social systems phase, starting with the visible playtest problems before expanding to lobby/accounts.

Priority order is tracked in `docs/PHASE_11_PLAN.md`.

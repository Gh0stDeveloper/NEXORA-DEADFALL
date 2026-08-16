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

Already present/working before Phase 11:

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

Phase 11 first milestone now adds in source:

- persistent camera sensitivity and volume/HUD-layout settings foundation;
- upper-HUD separation (Campaign mission left, Horde stats right);
- circular semi-transparent vector-icon mobile action controls;
- in-match sensitivity quick panel;
- moon/night readability tuning;
- camera-mounted toggleable SpotLight3D flashlight;
- persistent client guest identity foundation;
- dedicated-server guest verifier/challenge store;
- new pre-match lobby scene with Solo/Duo/Squad presentation, party slots and character selection shell;
- data-driven two-slot character catalog awaiting the developer's real 3D model files;
- Phase 11 VPS/CI smoke gate.

## Player controls target

Mobile controls must include:

- Virtual movement joystick.
- Run.
- Jump.
- Crouch.
- Prone.
- Flashlight.
- A single camera-cycle control that switches:
  1. first person;
  2. third-person rear;
  3. third-person front.

HUD buttons should use icons rather than text wherever practical. Avoid emoji in game UI.

## User assets

The developer already has downloaded 3D assets ready for integration, including:

- two distinct playable-character models;
- zombie models.

These real model files are not yet present in the Git repository. Do not invent replacements and present them as final assets. The Phase 11 character catalog uses placeholders until the actual assets are uploaded/imported.

Additional environment assets are still needed: low-poly walls, houses, abandoned vehicles and urban debris. Vehicle fire should use particles/shaders rather than a static fire mesh.

## Immediate gameplay/UI problems

### HUD overlap

The Mission panel and Wave/Score panel overlapped in the upper-left area in the first real-device build. Phase 11 moves Horde stats to a dedicated upper-right panel while Campaign mission/objective information remains on the left. Continue testing on multiple Android aspect ratios and refine rather than reintroducing independent overlapping coordinates.

### Camera sensitivity

Touch camera sensitivity felt too low in the first real-device playtest. Sensitivity is now a persistent user preference with range `0.10–1.00`; the controller maps the user-facing value to radians-per-pixel through `value * 0.01`. Current Phase 11 default is `0.50` pending physical-device feedback.

### Night visibility

Night scenes were too dark. Phase 11 now uses a brighter ambient/exposure baseline, a cool moon DirectionalLight3D and a player SpotLight3D flashlight. Keep night readable but visibly dark; do not turn it into daytime.

### Mobile HUD controls

Target/current Phase 11 direction:

- circular;
- semi-transparent;
- icon-based;
- larger and thumb-friendly;
- sufficiently separated;
- obvious pressed-state visual feedback.

### Audio

Audio integration remains pending:

- gunshots;
- zombie growls/vocals;
- ambient environment sound;
- background music;
- UI feedback sounds.

## Lobby system target

A pre-match lobby should exist before normal visible-client matches. Headless/server/explicit connection test paths may bypass it for automation.

Required final behavior:

- Select Solo / Duo / Squad.
- Players can freely join or leave Duo/Squad parties.
- Only the party leader can kick members.
- Only the party leader can start the match.
- Lobby text chat.
- Lobby visually shows the selected character for the local player.
- Duo/Squad lobby also shows selected characters for all party members.
- Lobby must be visually designed, not only functional.

Visual direction: create an original DEADFALL composition that combines the useful hierarchy of modern survival/mobile shooter lobbies: a prominent central full-body character/operator stage, clear character selection, a tactical mode/start bar, and a right-side party composition. Do not copy Free Fire or Call of Duty logos, artwork or proprietary UI assets.

Current Phase 11 shell already provides:

- central 3D operator preview viewport;
- left navigation;
- right four-slot party rail;
- Solo/Duo/Squad formation selector;
- leader-labelled local slot;
- large start action;
- character selection overlay with two data-driven slots.

Only Solo currently transitions to local Campaign. Duo/Squad party creation, invitation, authoritative leader rules and matchmaking/start flow are the next networking block.

## Guest account target and chosen architecture

Full registration is not required yet. Guest identity is the first account model.

User-facing requirements:

- Server recognizes each guest account by a stable unique ID.
- Player chooses username.
- Username maximum: 12 characters.
- No emoji in username.
- Username must be unique on the server.
- The password/authentication secret is **generated automatically by the game**, never chosen by the player.
- Guest account persists across app sessions.
- Local account data is stored in a `.dat` file whose payload is readable plain-text JSON.
- Server remains authoritative for identity uniqueness and authentication acceptance.

Chosen client storage:

```text
user://account/guest.dat
```

This file is mutable app data and therefore belongs in Godot `user://`, which maps to the app-private sandbox on Android. Do **not** use OBB/asset packs for credentials or mutable account data. OBB/Play Asset Delivery can be considered later only for large packaged game assets if distribution size requires it.

Current local JSON fields include:

```json
{
  "schema_version": 1,
  "guest_id": "gst_...",
  "username": "...",
  "auth_secret": "game-generated 256-bit secret",
  "selected_character": "operator_01",
  "created_unix": 0
}
```

The local `auth_secret` is intentionally readable by the game inside its private app storage because this is a recoverable guest credential, not a human-entered password.

Server-side rule:

- never persist the raw `auth_secret`;
- enroll/store `SHA-256(auth_secret)` as the secret verifier;
- issue short-lived random authentication nonces;
- client answers with HMAC-SHA256 using the derived verifier key;
- server compares proofs in constant time;
- username uniqueness remains server-side;
- add rate limits to enrollment/rename/challenge/auth RPCs when they are wired into the live network session.

This is an original standard-cryptography design; do not claim it duplicates any proprietary Garena/Free Fire authentication implementation.

## Packaged assets / visibility

Normal immutable game assets should remain imported through Godot and packed into exported project resources/APK/PCK rather than copied into user-accessible folders. Do not put source assets or editable model files into `user://` simply to make them available at runtime. OBB/Play Asset Delivery is a distribution/size decision, not an authentication/storage mechanism.

## Settings target

### In-match settings

Keep this intentionally minimal to avoid disrupting gameplay:

- camera/touch sensitivity only initially.

Phase 11 now has a quick sensitivity panel in the mobile HUD.

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

The edited HUD layout must persist between sessions and support safe reset-to-default. The Settings autoload already contains the versioned data model; the visual editor is still pending.

## Design/engineering constraints

- Android-first UX; targets must be touch-friendly.
- Avoid emoji in production game UI; use icons/assets.
- Prefer scalable layouts over fixed pixel coordinates.
- Persist user preferences through the central Settings autoload rather than scattering save logic through gameplay scripts.
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

## Next development phase/current continuation

Phase 11 is active. Continue from `docs/PHASE_11_PLAN.md` and Issue #15. The first milestone is implemented in source but must pass the new Phase 11 headless/VPS gate and a new physical Android playtest before it is considered accepted.

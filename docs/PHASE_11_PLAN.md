# Phase 11 — Mobile gameplay polish, settings and lobby foundation

Phase 11 starts after the first successful real-device Closed Beta playtest. The objective is to convert the technically functional vertical slice into a much more usable Android game while laying the foundations for the social/lobby layer.

## Entry criteria already met

- Production VPS updater completed successfully.
- Android Release APK builds successfully on the VPS.
- APK signature verification succeeds.
- APK is publicly downloadable through the production Next.js/Nginx portal.
- Physical Android install completed successfully.
- Game launches and is playable on a real Android device.

## Milestone 11.1 — implemented in source, awaiting VPS/device validation

Implemented on `agent/bootstrap-deadfall`:

- [x] Settings persistence foundation with schema version.
- [x] Touch sensitivity range `0.10–1.00`, current default `0.50`, applied immediately by PlayerController.
- [x] In-match sensitivity quick panel.
- [x] Horde Wave/Score/Kills moved to a compact upper-right panel so Campaign mission UI can remain upper-left.
- [x] Circular semi-transparent vector-icon mobile action controls and pressed feedback.
- [x] Mobile flashlight action plus camera-mounted SpotLight3D.
- [x] Night ambient/exposure/moon readability pass.
- [x] Data model for persistent HUD position/scale/opacity/visibility.
- [x] Game-generated guest credential foundation in `user://account/guest.dat`.
- [x] Server-side verifier/challenge account store foundation.
- [x] Data-driven two-character catalog shell.
- [x] Pre-match lobby shell with central 3D operator stage, character selection, party rail, Solo/Duo/Squad selector and leader-labelled local slot.
- [x] Visible clients boot through lobby; headless/server/explicit connection paths retain direct boot for automation.
- [x] Phase 11 smoke script added to CI and VPS updater.

Not yet accepted until:

- [ ] `phase11_smoke.gd` passes on the real VPS with Godot 4.6.3.
- [ ] Android Release rebuild succeeds.
- [ ] New APK is installed and tested on the physical Android device.
- [ ] User confirms sensitivity, HUD spacing, night readability, flashlight and lobby layout feel correct enough to continue.

## Workstream A — Playtest fixes first

### A1. HUD top-area redesign

Problem: Mission and Wave/Score/Kills UI overlapped in the upper-left corner.

Current implementation:

- Campaign mission/objective remains on the upper-left.
- Horde Wave/Score/Kills/Enemies/Population are grouped in a compact upper-right panel.
- SafeArea remains active.

Still required:

- verify on multiple Android aspect ratios/notches;
- tune size/spacing from physical screenshots if needed.

### A2. Camera sensitivity preference

Implemented foundation:

- persistent touch sensitivity;
- range `0.10–1.00`;
- current default `0.50`;
- immediate application without scene reload;
- in-match quick sensitivity UI;
- same Setting will feed the future full settings screen.

### A3. Night readability + flashlight

Implemented foundation:

- tuned WorldEnvironment ambient/exposure/brightness;
- cool low-energy moon DirectionalLight3D;
- player flashlight using SpotLight3D on the first-person camera rig;
- mobile flashlight button and desktop `F` input;
- flashlight controller kept as presentation/input logic, not authoritative combat state.

Still required:

- physical Android readability/performance check;
- decide later whether flashlight should visually follow TPS cameras or remain character-forward while TPS is active;
- optional future battery/resource mechanic.

### A4. Mobile HUD visual redesign

Implemented foundation:

- circular semi-transparent controls;
- original vector icons drawn in GDScript, not emoji/text labels;
- larger touch targets;
- new thumb spacing;
- visual pressed scale/accent feedback;
- actions still feed PlayerInput and the existing command/authority path.

### A5. Audio foundation

Pending next block:

- Master bus.
- Music bus.
- SFX bus.
- UI bus.
- Optional Ambience bus.
- weapon fire;
- zombie vocal/growl;
- ambience;
- music;
- UI press/confirm/back.

Settings persistence for master/music already exists and will be bound once buses/UI are created.

## Workstream B — Settings/HUD editor

### B1. Settings persistence

Implemented fields:

- touch camera sensitivity;
- master volume;
- music volume;
- HUD layout schema/version;
- per-control normalized position/scale/opacity/visibility.

Path:

```text
user://deadfall_settings_v1.json
```

### B2. In-game settings

Implemented initial scope:

- sensitivity slider;
- open/close via settings icon.

### B3. Full main-menu settings

Pending:

- sensitivity;
- master volume;
- music volume;
- HUD editor entry;
- reset HUD to default.

### B4. HUD editor

Persistence/data contract exists. Visual editor still pending:

- drag/reposition;
- scale/size;
- opacity;
- visibility;
- reset individual control;
- reset all controls;
- keep controls within recoverable screen bounds.

## Workstream C — Character asset integration

The developer already has two distinct playable-character models and zombie models, but the actual model files are not yet present in Git.

Phase 11 now contains a data-driven character catalog with stable IDs:

- `operator_01`
- `operator_02`

The lobby currently uses original placeholder geometry. Once the real assets are uploaded/imported, replace only each catalog/model resource mapping rather than hard-coding models into lobby/gameplay scripts.

Character definition/catalog must continue to support:

- stable character ID;
- display name;
- model/scene resource;
- portrait/preview asset;
- animation mapping;
- optional future cosmetic metadata.

## Workstream D — Guest identity foundation

### Chosen local guest file

```text
user://account/guest.dat
```

It is plain-text JSON in the Android app-private user directory. Do not use OBB or asset packs for credentials.

Current shape:

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

Rules:

- password/auth secret is generated automatically by the game;
- user does not choose the password;
- username is user-chosen, 1–12 ASCII letters/numbers/underscore for the first implementation, which excludes emoji/control characters;
- guest ID and secret use cryptographically secure random bytes;
- server never persists the raw secret.

### Server verifier/auth foundation

Current design:

- client derives `SHA-256(auth_secret)` verifier;
- server stores verifier, username and selected character;
- server issues short-lived cryptographically random challenge nonce;
- client builds HMAC-SHA256 proof using the derived verifier key;
- server compares proof in constant time;
- username uniqueness index is case-insensitive.

Still required before live deployment of identity RPCs:

- wire enrollment/challenge/proof into ClosedBetaNetworkSession;
- rate-limit enroll/auth/rename;
- bind authenticated guest ID to peer/session;
- reject rename conflicts atomically;
- add reconnect/auth integration tests.

## Workstream E — Lobby foundation

### Visual direction

Use an original DEADFALL composition inspired only by useful interaction patterns from modern mobile survival/shooter lobbies:

- prominent full-body character stage in center;
- character-selection section;
- strong bottom mode/start bar;
- tactical party/squad rail on the right;
- compact identity/navigation on the left/top.

Do not copy Free Fire/Call of Duty artwork, logos or proprietary assets.

### Current lobby shell

Implemented:

- username setup overlay for a new guest;
- central SubViewport 3D operator preview;
- two-character selection overlay;
- Solo/Duo/Squad formation selector;
- four party slots;
- local leader label;
- large start action;
- character selection persists to guest profile;
- normal visible startup enters the lobby first.

Current transition rule:

- Solo can start local Campaign.
- Duo/Squad are visible but intentionally refuse start until authoritative party creation/member flow exists.

### Party state — next networking block

Server-authoritative party model must track at least:

- party/lobby ID;
- leader guest/player ID;
- selected game mode;
- members;
- ready/presence state if later required;
- selected character per member;
- lobby state (`OPEN`, `STARTING`, `IN_MATCH`, etc.).

Permissions:

- members leave freely;
- leader can kick;
- non-leaders cannot kick;
- only leader can start;
- capacity and leadership validated server-side.

### Lobby chat — pending

- text only initially;
- server relay/validation;
- length limits;
- rate limits / anti-spam;
- reject control characters;
- separate chat from authoritative gameplay RPCs.

## Workstream F — Environment expansion

Still needed:

- low-poly walls/barriers;
- houses/buildings;
- abandoned cars;
- urban debris;
- road/sidewalk props.

Vehicle fire should be implemented with GPUParticles3D plus shader/material effects, not a final static fire mesh.

Performance rules:

- shared materials where possible;
- LOD/visibility distances for environment props;
- avoid excessive realtime lights;
- pool/reuse repeating effects where useful;
- profile on Android before moving systems to GDExtension.

## Revised execution order from current head

1. Validate Milestone 11.1 on VPS and physical Android.
2. Fix any real-device layout/sensitivity/night/lobby issues found.
3. Audio buses + initial SFX/music and volume settings.
4. Full Settings screen + functional HUD editor.
5. Import/integrate the developer's two real playable character assets.
6. Wire guest enrollment/authentication into the live network handshake with rate limits.
7. Server-authoritative party/lobby state + invitation/join/leave/kick/start.
8. Display real party member character previews.
9. Lobby text chat.
10. Environment asset expansion and particle fire.
11. Multiplayer/Android soak tests and polish.

## Acceptance criteria

Phase 11 is not complete until:

- HUD no longer overlaps on supported Android aspect ratios;
- sensitivity feels usable and persists across restarts;
- night gameplay is readable and flashlight works appropriately across camera modes;
- mobile controls are icon-based and configurable;
- master/music volume persists;
- HUD editor persists and can safely reset;
- both real playable-character models can be selected/spawned;
- guest identity persists locally and is validated by server;
- Duo/Squad leader/member permissions are enforced server-side;
- lobby shows selected party characters;
- lobby text chat has validation/rate limiting;
- real Android build/install remains successful;
- offline and online gameplay remain on one shared gameplay implementation.

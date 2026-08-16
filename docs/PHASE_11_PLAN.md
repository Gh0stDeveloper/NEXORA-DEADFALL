# Phase 11 — Mobile gameplay polish, settings and lobby foundation

Phase 11 starts after the first successful real-device Closed Beta playtest. The objective is to convert the technically functional vertical slice into a much more usable Android game while laying the foundations for the social/lobby layer.

## Entry criteria already met

- Production VPS updater completed successfully.
- Android Release APK builds successfully on the VPS.
- APK signature verification succeeds.
- APK is publicly downloadable through the production Next.js/Nginx portal.
- Physical Android install completed successfully.
- Game launches and is playable on a real Android device.

## Workstream A — Playtest fixes first

### A1. HUD top-area redesign

Problem: Mission and Wave/Score/Kills UI overlap in the upper-left corner.

Target:

- Treat Mission and combat status as one coordinated responsive HUD region.
- Mission/objective information should have its own readable block.
- Wave, score and kills should be compact and visually separate.
- Respect Android safe areas/notches.
- Avoid hard-coded coordinates where anchors/containers can be used.
- Add regression coverage for expected node/layout structure where practical.

### A2. Camera sensitivity preference

- Add persistent touch sensitivity setting.
- Slider range: approximately `0.1–1.0`.
- Sensible default should be selected from physical-device testing.
- Apply immediately without scene reload.
- In-game pause/settings exposes sensitivity only.
- Main-menu settings exposes the same underlying preference.

### A3. Night readability + flashlight

- Tune WorldEnvironment for readable darkness without turning night into daylight.
- Add low-energy moon DirectionalLight3D with soft shadows.
- Add player flashlight using SpotLight3D attached to the active camera/view rig.
- Add mobile flashlight control with icon and pressed/on state.
- Flashlight state should survive FPS/TPS camera changes without duplicating lights.
- Consider battery/resource gameplay later; Phase 11 only requires robust on/off behavior.

### A4. Mobile HUD visual redesign

- Circular semi-transparent controls.
- Real icons, not text labels or emoji.
- Larger touch targets.
- Thumb-friendly spacing.
- Visual pressed feedback.
- Controls must still feed the existing PlayerCommand/authority pipeline rather than adding direct gameplay mutations.

### A5. Audio foundation

Add an explicit audio architecture before dropping sounds directly into scenes:

- Master bus.
- Music bus.
- SFX bus.
- UI bus.
- Optional Ambience bus.

Initial assets/events:

- weapon fire;
- zombie vocal/growl;
- ambience;
- music;
- UI press/confirm/back.

Settings must persist master and music volumes at minimum.

## Workstream B — Settings/HUD editor

### B1. Settings persistence

Use one settings service/autoload as the source of truth.

Required persisted fields initially:

- touch camera sensitivity;
- master volume;
- music volume;
- HUD layout schema/version;
- per-control HUD position/scale/opacity/visibility.

Use a schema version so future UI changes can migrate/reset old layouts safely.

### B2. In-game settings

Keep minimal:

- sensitivity slider;
- close/back.

Do not put the full HUD editor or long graphics menus into the active match pause flow initially.

### B3. Full main-menu settings

- sensitivity;
- master volume;
- music volume;
- HUD editor entry;
- reset HUD to default.

### B4. HUD editor

For every supported mobile control:

- drag/reposition;
- scale/size;
- opacity;
- visibility;
- reset individual control;
- reset all controls;
- prevent controls from becoming permanently inaccessible off-screen.

## Workstream C — Character asset integration

The developer already has two distinct playable-character models and zombie models.

Integrate characters through a data-driven character definition rather than hard-coding model paths into lobby/gameplay scenes.

Character definition should be able to grow to include:

- stable character ID;
- display name;
- model/scene resource;
- portrait/preview asset;
- animation mapping;
- optional future cosmetic metadata.

The selected character must be reusable by both gameplay spawning and the future lobby preview.

## Workstream D — Guest identity foundation

Do this before the visual multiplayer lobby so lobby state has a real identity model.

### Local guest file

A local `.dat` file contains plain-text JSON readable by the app. Suggested shape:

```json
{
  "schema": 1,
  "guest_id": "...",
  "username": "...",
  "auth_secret": "..."
}
```

Do not store a plaintext human password. If a password-like recovery/auth secret is required, use generated high-entropy secret material locally and store only an appropriate verifier/hash on the server.

### Server rules

- Server assigns/accepts one stable unique guest ID.
- Username maximum 12 characters.
- Reject emoji/control characters.
- Normalize username consistently before uniqueness checks.
- Username uniqueness enforced atomically by the server.
- Apply rate limiting to create/rename/auth attempts.
- Never let client-provided guest data confer gameplay authority.

## Workstream E — Lobby foundation

### Party modes

- Solo: 1 player.
- Duo: maximum 2.
- Squad: maximum 4.

### Party state

Server-authoritative party model should track at least:

- party/lobby ID;
- leader guest/player ID;
- selected game mode;
- members;
- ready/presence state if later required;
- selected character per member;
- lobby state (`OPEN`, `STARTING`, `IN_MATCH`, etc.).

### Permissions

- Members can leave freely.
- Leader can kick members.
- Non-leaders cannot kick.
- Only leader can start.
- Server validates capacity and all leadership operations.

### Lobby chat

- Text only initially.
- Server relay/validation.
- Length limits.
- Rate limits / anti-spam.
- Reject problematic control characters.
- Do not mix lobby chat messages with authoritative gameplay RPCs.

### Lobby presentation

- Visually polished Android-first scene.
- Local selected character shown prominently.
- Duo/Squad slots show each member's selected character.
- Leader visually identifiable.
- Join/leave/start actions use icons/layout appropriate for touch.

## Workstream F — Environment expansion

Needed low-poly environment content:

- walls/barriers;
- houses/buildings;
- abandoned cars;
- urban debris;
- road/sidewalk props.

Vehicle fire should be implemented with GPUParticles3D plus shader/material effects. Avoid a static fire mesh as the final effect.

Performance rules:

- shared materials where possible;
- LOD/visibility distances for environment props;
- avoid excessive realtime lights;
- pool/reuse repeating effects where useful;
- profile on Android before moving systems to GDExtension.

## Recommended execution order

1. HUD overlap fix/redesign.
2. Persistent sensitivity slider and improve physical-device camera feel.
3. Night lighting + flashlight.
4. Mobile control/icon redesign.
5. Audio buses + initial SFX/music and volume settings.
6. Full Settings screen + HUD editor foundation.
7. Integrate two playable character assets through a data-driven character system.
8. Guest identity persistence + server validation.
9. Server-authoritative party/lobby state.
10. Lobby scene + character previews.
11. Lobby chat.
12. Environment asset expansion and particle fire.
13. Multiplayer/Android soak tests and polish.

## Acceptance criteria

Phase 11 should not be considered complete until:

- HUD no longer overlaps on supported Android aspect ratios.
- sensitivity feels usable and persists across restarts;
- night gameplay is readable and flashlight works across camera modes;
- mobile controls are icon-based and configurable;
- master/music volume persists;
- HUD editor persists and can safely reset;
- both available playable-character models can be selected/spawned;
- guest identity persists locally and is validated by server;
- Duo/Squad leader/member permissions are enforced server-side;
- lobby shows selected party characters;
- lobby text chat has validation/rate limiting;
- real Android build/install still succeeds;
- offline and online gameplay remain on one shared gameplay implementation.

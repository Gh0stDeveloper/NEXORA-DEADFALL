# NEXORA: DEADFALL — Game Design Document

**Studio:** Ghost Developer / Nexora  
**Platform:** Android, landscape  
**Engine:** Godot 4  
**Target content rating:** Mature / 18+ depending on territory  
**Document status:** Living document  
**Version:** 0.1.0

## 1. Executive summary

NEXORA: DEADFALL is a first/third-person zombie survival shooter for Android. Players face outbreaks and waves of infected in campaign missions, objective-based normal matches and endless horde sessions, solo or in closed co-op groups of 2–4 players.

The combat identity is built around responsive shooting, positional damage and scalable but uncensored gore. Dismemberment is not purely cosmetic: destroying legs can force a zombie into a crawling state, destroying an arm can reduce attack capability, and critical head destruction can end the threat immediately.

## 2. Design pillars

1. **One simulation, multiple modes.** Offline and online share gameplay rules.
2. **Mobile-first gunplay.** Touch controls are a first-class design target, not a desktop UI port.
3. **Server authority online.** Clients submit intent; the server resolves combat and match state.
4. **Mechanical gore.** Body-part damage affects enemy behavior.
5. **Performance scaling.** Quality tiers reduce cost without removing the game identity.
6. **Co-op before matchmaking.** Closed rooms by code are the first multiplayer milestone.

## 3. Game modes

| Mode | Players | Connectivity | Core loop |
|---|---:|---|---|
| Campaign | 1, later 2–4 | Offline / Online | Missions, objectives, story, unlocks |
| Normal | 2–4 or offline bots | Online / Offline | Defined objective and match duration |
| Endless Horde | 1–4 | Online / Offline | Increasing waves until squad defeat |
| Duo / Squad | 2 / 3–4 | Online | Closed room by short join code |

## 4. Player controls

- Left virtual joystick for movement.
- Right-side touch region for aim/look.
- Dedicated run, jump, crouch and prone controls.
- Fire, aim, reload and weapon interaction controls.
- One camera button cycles first person → rear third person → front third person.
- Fixed landscape orientation with safe-area support.
- Later HUD editor: position, size, opacity, sensitivity and optional auto-sprint.

## 5. Combat

Damage is represented as an event containing attacker, victim, weapon, amount, type, body part, hit position, direction, penetration, critical state and simulation tick.

Initial damage types: bullet, explosive, fire, melee, fall and environment.

Initial body zones: head, chest, abdomen, both arms and both legs.

## 6. Dismemberment and gore

Characters use prepared detachable body sections rather than runtime mesh cutting. When a threshold is exceeded:

1. Hide the attached limb mesh.
2. Reveal the wound/stump variant.
3. Spawn or activate a pooled rigid-body limb.
4. Apply hit impulse.
5. Emit pooled blood particles.
6. Place a budgeted decal.
7. Update AI capabilities if the body part affects movement or attacks.

Gore budgets by initial quality tier:

| Tier | Detached parts | Decals | Particle intensity |
|---|---:|---:|---|
| Smooth | 4 | 8 | Low |
| Standard | 8 | 20 | Medium |
| Ultra | 16 | 40 | High |
| Ultra HD | 32 | 80 | Maximum |

Oldest cosmetic objects are recycled through object pools when the budget is exceeded.

## 7. Zombie archetypes

Initial state model: Idle → Search → Chase → Attack → Dead, with Stagger, Stun, Crawl and Rage as secondary states.

Planned archetypes:

- Walker: baseline infected.
- Runner: low durability, high pressure.
- Tank: slow, resilient, stagger-resistant.
- Screamer: attracts or reinforces nearby infected.
- Crawler: native crawler or a damaged zombie missing leg function.
- Elite/Boss: later milestone, used sparingly.

## 8. Horde pacing

Difficulty should increase by composition and pressure, not only enemy health. The Horde Director will observe current round, surviving players, player health, ammunition pressure, kill rate, alive enemies and player separation to schedule spawn groups.

## 9. Multiplayer

Dedicated Godot headless server on a VPS. ENet/UDP is the primary transport. The server owns player-authoritative validation, enemy AI, hit resolution, health, spawns, drops and match state. Clients predict local movement and interpolate remote snapshots.

The first lobby system uses a 4–6 character code. Matchmaking, public rooms and social invitations come later.

## 10. Offline model

Offline mode uses LocalAuthority with no remote transport. The gameplay simulation remains identical at the system boundary so weapons, AI, waves and damage do not fork into separate offline implementations.

## 11. Graphics tiers

| Setting | Smooth | Standard | Ultra | Ultra HD |
|---|---|---|---|---|
| Render scale | 60–70% | 85–100% | 100% | 100%+ where viable |
| Textures | Low | Medium | High | Maximum |
| Shadows | Minimal/off | Medium | High | High + extras |
| Gore | Reduced budget | Normal | High | Maximum |
| Draw distance | Short | Medium | Long | Long |
| Post-processing | Off | Partial | Full | Full |

Automatic first-run recommendation may be added, but the user keeps manual control.

## 12. Progression and systems still to design

Weapons, attachments, ammunition economy, armor, downed/revive, inventory, pickups, campaign progression, score economy, persistent unlocks, achievements, map objectives, accessibility, audio, adaptive music and anti-abuse telemetry each require a dedicated design pass before implementation.

## 13. Content/compliance direction

The game targets mature audiences and will declare graphic violence and strong language accurately in store rating questionnaires. Privacy policy, terms/code of conduct and moderation design are required before public online launch. No third-party game trademarks, logos or proprietary assets are to be copied.

## 14. Vertical slice acceptance

The first playable vertical slice is complete when one test map supports player movement, run/jump/crouch/prone, all three cameras, one rifle, one zombie, basic AI, body-part hitboxes, death and a first pooled gore effect at stable performance on a representative Android device.

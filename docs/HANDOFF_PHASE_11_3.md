# NEXORA: DEADFALL — Phase 11.3 handoff

This file is the durable continuation point for a new ChatGPT/Codex conversation.

## Repository state

- Main repository: `Gh0stDeveloper/NEXORA-DEADFALL`
- Active development branch: `agent/bootstrap-deadfall`
- Draft PR: `#1`
- Phase 11 tracker: issue `#15`
- **Do not merge PR #1 unless the user explicitly requests it.**
- Implementation anchor immediately before this handoff document was created: `45137a033595b9e86d146b03423dfb09d3dda6c5`.
- Always fetch the branch/PR again at the start of a new chat because commits after this handoff can move the head.

Production domain currently used by the project:

`nexoradeadfall.duckdns.org`

## Phase 11.3 completed source work

### Guest identity and login carried from Phase 11.2

- visible clients enter `LoginGate` first;
- `TOCA PARA INICIAR` flow;
- guest account is the only provider for now;
- local generated secret, no human plaintext password;
- server-side username uniqueness;
- challenge/HMAC returning-user authentication;
- server-generated 10-digit public player ID;
- persistent friends and direct messages;
- social control API exposed through HTTPS, localhost-only backend.

### Complete social squad management

Squads are server-authoritative social objects, separate from gameplay processes.

Implemented UI/server contracts:

- Solo / Duo / Squad selection;
- six-character server-generated squad code;
- join by code;
- leader/member state;
- public player IDs;
- member character and ping display;
- leader `EXPULSAR` control;
- `SALIR` control;
- squad chat;
- friends + incoming requests + private messages;
- party state locks while matchmaking/match assignment is active;
- poll-based lobby refresh (currently ~1.25 s).

### Match Orchestrator

`src/server/MatchOrchestrator.gd`

Current architecture:

1. leader requests match through HTTPS control API;
2. orchestrator snapshots the authoritative current party;
3. same party gets exactly one `match_id`;
4. one UDP port is allocated from `24600–24749`;
5. every member gets a unique 64-hex admission ticket;
6. one child Godot dedicated process is started for that party;
7. child process loads `MatchAdmission` and only accepts reserved tickets;
8. child initializes ENet/arena/admission and writes a real `.ready` marker;
9. parent publishes status `READY` only after that marker exists;
10. every party member receives the same `match_id`, host and port, but only their own private join ticket;
11. each client leaves the lobby and connects to that same child process.

This guarantees that players already in the same squad do not independently matchmaking into different matches.

### Match admission / isolation

`src/server/MatchAdmission.gd`

- tickets are random 32-byte values represented as 64 hex characters;
- IP/port knowledge alone is insufficient to enter an orchestrated match;
- missing/invalid tickets are rejected before a gameplay entity is accepted;
- the same ticket cannot be active on two peers simultaneously;
- username/public ID/selected character are taken from the server-created admission record, not trusted from the joining client.

### Match lifecycle

`src/server/MatchInstanceGuard.gd`

- startup grace: 90 s;
- empty-after-use grace: 75 s;
- absolute child lifetime: 2 hours;
- parent monitors child PIDs and cleans stale assignments/config files;
- parent shutdown kills its children to prevent orphan match processes.

### Server authority / anti-cheat foundation

The Android client submits input/intention only. It is not trusted for:

- position;
- velocity authority;
- health;
- damage;
- victim/hit result;
- ammo;
- reload completion;
- zombie state;
- Horde/Campaign state.

Server behavior:

- real server-owned Player nodes run movement physics and `move_and_slide()`;
- client prediction is presentation/responsiveness only and reconciles to server position;
- server weapon owns ammo/cadence;
- server camera/physics world generates hitscan ray;
- server chooses hitbox/body part;
- server constructs damage events;
- `Game.authority` resolves damage/health;
- malformed/oversized/rate-limited network input is rejected/struck;
- remote movement input is neutralized after ~350 ms without a new valid command, preventing stale-input ghost movement after packet/Internet loss.

Reference: `docs/NETWORK_AUTHORITY_AND_MATCHMAKING.md`.

### Ping system

`NetworkTelemetry` is a global client autoload.

Outside match:

- measures HTTPS/control-server RTT.

Inside match:

- ENet ping/pong on an independent unreliable ordered channel becomes the preferred value.

Display semantics requested by the user:

- <= 25 ms raw -> display `0` / `EXCELENTE`;
- 26–70 -> actual ping / `BUENO`;
- 71–140 -> actual ping / `MEDIO`;
- > 140 -> actual ping / `ALTO`;
- unavailable/no connection -> `+999` / `SIN CONEXIÓN`.

Ping is also surfaced in squad/friend presence UI. Presence ping is cosmetic and is not trusted for gameplay decisions.

### Current network optimizations

Already present or preserved:

- client prediction;
- authoritative reconciliation;
- remote interpolation;
- server snapshots over `unreliable_ordered`;
- configurable snapshot frequency (baseline 15 Hz rather than 60-Hz full-state replication);
- per-client nearest-zombie relevance selection;
- zombie detail budget;
- maximum snapshot byte budget and detail trimming;
- compact input command whitelist rather than sending transforms;
- reliable one-shot RPCs for join/fire/reload where required;
- ping on a separate unreliable channel;
- isolated 1–4 player match processes so unrelated parties do not share replica traffic.

### Provisional 3D model pipeline

Source repository:

`Gh0stDeveloper/Objetos3D`

Observed GLB assets at Phase 11.3 checkpoint:

- low-poly survival character by Daren;
- Animated Character Base by J-Toastie;
- Animated Zombie by Quaternius;
- Zombie by cs_aaron.

Canonical build staging:

- `operator_01.glb`
- `operator_02.glb`
- `zombie_animated.glb`
- `zombie_static.glb`

`deploy/vps/update.sh` runs `scripts/assets/sync_objetos3d.sh` before Godot import/export on relevant changes.

The binary GLBs are ignored by the main repo and staged during production builds.

Character model support:

- MARA -> `operator_01`;
- DANTE -> `operator_02`;
- player replicas receive authoritative `selected_character` in server snapshot;
- PlayerModelPresenter loads the matching GLB with fallback mesh;
- lobby central preview has a dynamic model preview bridge with fallback capsule.

Zombie support:

- intact zombies may show the provisional animated zombie;
- authoritative collision/hitboxes remain the existing DEADFALL ones;
- on damage the visual swaps to the existing segmented gore-ready rig so wounds/dismemberment remain valid.

At the checkpoint when `Objetos3D` was inspected, a structure/building model was **not yet visible in the recursive main-branch tree**. Integrate it through a stable canonical mapping when it appears.

Third-party licensing is not assumed. See `docs/THIRD_PARTY_3D_ASSETS.md`; verify original source/license/attribution/redistribution rights before a public/commercial release.

### VPS networking

- UDP 24560: legacy/base gameplay;
- TCP 24561: legacy room directory;
- TCP 24562: localhost-only control/social/match API — DO NOT expose directly;
- TCP 80/443: portal + HTTPS API proxy;
- UDP 24600–24749: orchestrated party match instances.

`deploy/vps/update.sh` opens the dynamic UDP range in UFW.

For Oracle Cloud the Security List/NSG must also allow UDP 24600–24749; UFW alone is insufficient.

## Validation state at handoff

Source-side smoke coverage has been expanded in `scripts/ci/phase11_smoke.gd` for matchmaking, authority, ping, model presenters, social API and VPS deployment contracts.

Historical GitHub Actions for this project have repeatedly failed before executing runner steps because of the account billing/spending condition (`steps=null`). Do not claim CI is green unless a current workflow actually executes steps and succeeds.

The exact Phase 11.3 code still needs real VPS/Godot/Android validation after deployment.

## First actions in the next chat

1. Fetch current PR #1 and branch head; do not assume the anchor SHA above is still current.
2. Inspect current GitHub Actions for that exact head.
3. On the VPS update to the latest branch and run:

```bash
sudo /opt/nexora-deadfall/deploy/vps/update.sh --force
```

4. The update should synchronize `Objetos3D`, import Godot, run Phase 11 smoke, build the portal/APK, restart the control server and validate the HTTPS API.
5. Confirm Oracle/UFW UDP `24600–24749` exposure.
6. Run two real Android devices/accounts:
   - create/join same squad code;
   - verify both see one party;
   - leader starts match;
   - verify both receive same match ID/host/port;
   - verify each has different join ticket;
   - verify both load into the same game instance;
   - verify a non-member/ticketless client is rejected;
   - verify leader/member UI, kick/leave restrictions;
   - verify ping 0/good/high/+999 behavior under network changes;
   - verify character models and zombie model/gore fallback.

## Next development after Phase 11.3 validation

Prioritize in roughly this order unless the user changes direction:

### Networking / match services

- child-process heartbeat IPC instead of readiness-only marker;
- authoritative parent `IN_MATCH`, mission-complete and crash status;
- orchestrated-match reconnect scoped to match/ticket identity;
- gracefully return the whole party to lobby after a match;
- match result summary and party preservation;
- server-side movement/fire anomaly scoring beyond direct authority checks;
- bandwidth/RPC metrics;
- packet loss/jitter diagnostics;
- adaptive per-peer snapshot frequency;
- command coalescing/heartbeat without losing action serials;
- delta/bit-packed snapshots after measurement proves useful;
- multi-region/region-aware matchmaking only when more VPS regions exist.

### Squad/lobby presentation

- show all party members as actual 3D character previews/lineup, not only the local central model + member cards;
- invitations directly from friends list into squad;
- ready/not-ready member state if desired;
- richer presence/activity states;
- better chat unread indicators/notification UX;
- replace polling with a more efficient realtime channel when scale requires it.

### Gameplay/mobile Phase 11 remaining items

Issue #15 still includes work beyond identity/social/matchmaking:

- finish HUD overlap/polish on physical Android;
- complete settings UI and persistence coverage;
- HUD editor: position/size/opacity/visibility/reset;
- audio bus architecture and real weapon/zombie/ambience/music/UI sounds;
- refine night readability/flashlight based on device tests;
- refine circular touch controls/press feedback;
- broader low-poly urban environment and fire/VFX;
- real Android + multiplayer soak/regression testing.

### 3D/content

- integrate the structure/building when it appears in `Objetos3D`;
- inspect actual imported GLB scale/orientation/animation names and tune catalog transforms;
- map walk/run/attack/downed/death animations rather than idle-only fallback;
- eventually replace provisional third-party models with original DEADFALL models while retaining stable runtime character IDs;
- verify/record all third-party model licenses before release.

### Release/operations

- keep PR #1 draft until explicitly asked otherwise;
- keep Issue #15 open until physical multiplayer and remaining Phase 11 acceptance criteria pass;
- do not add voice chat automatically; it remains a separate future feature.

## Useful files to inspect first in the next chat

- `docs/HANDOFF_PHASE_11_3.md`
- `docs/NETWORK_AUTHORITY_AND_MATCHMAKING.md`
- `docs/THIRD_PARTY_3D_ASSETS.md`
- `src/server/MatchOrchestrator.gd`
- `src/server/MatchAdmission.gd`
- `src/server/SocialService.gd`
- `src/server/ControlApiServer.gd`
- `src/network/ClosedBetaNetworkSession.gd`
- `src/network/NetworkTelemetry.gd`
- `src/social/SocialClient.gd`
- `src/lobby/LobbySocialOverlay.gd`
- `src/main/Main.gd`
- `scripts/assets/sync_objetos3d.sh`
- `deploy/vps/update.sh`
- `scripts/ci/phase11_smoke.gd`

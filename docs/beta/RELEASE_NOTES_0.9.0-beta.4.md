# NEXORA: DEADFALL — 0.9.0-beta.4

Version code: `900004`  
Channel: `closed_beta`  
Protocol: `2`  
Target Android API: `36`

## Focus

Beta.4 is the presentation/performance candidate built on top of beta.3's gameplay/network hardening. It keeps the dedicated server authoritative and does not change the MTU-safe FastLZ wire protocol.

## Included

- Lobby 2.0 visual pass with animated atmosphere, improved contrast, touch-friendly buttons, a lit 3D operator stage and slow turntable preview.
- Shared imported-animation driver for lobby/player/zombie GLBs.
- Safe generic animation fallback for models that expose one neutral clip only, preventing bind/T-pose without fabricating semantic states.
- `operator_02` verified generic fallback: `mixamo_com`.
- Quaternius exact runtime mappings:
  - Idle: `Zombie|ZombieIdle`
  - Walk: `Zombie|ZombieWalk`
  - Run: `Zombie|ZombieRun`
  - Crawl: `Zombie|ZombieCrawl`
  - Attack: `Zombie|ZombieBite`
- Player/zombie visual GLBs disabled on dedicated/headless server processes.
- Mobile performance tuner now applies render scale, mesh LOD threshold, 3D MSAA and FPS target per quality tier.
- Zombie visual-distance culling by quality tier; gameplay AI, hitboxes, health and network authority are unaffected.
- Remote weapon presentation continues to consume authoritative per-weapon action sequences from replicated loadout snapshots.
- Added strict beta.4 Lobby/mobile presentation smoke and pinned model capability validation.

## Carried from beta.3

- Recoverable Lobby → Matchmaking → dedicated match loading flow with timeout/return to lobby.
- Game Over/Restart input-layer hardening.
- Mobile sprint toggle and haptics.
- HP/ammo HUD and weapon selector.
- Rifle, pistol and machete loadout.
- Authoritative finite ammunition, zombie ammo drops and replicated pickups.
- Day/night cycle with headless-safe server behavior.
- MTU-safe chunked snapshots and private per-player match admission tickets.

## Known asset limitation

`operator_02` currently exposes a single runtime clip named `mixamo_com`. Beta.4 uses it only as a neutral generic fallback. Separate Idle/Walk/Run/Attack/Death states require additional compatible clips or retargeted animations.

The current Quaternius GLB does not expose separately verified Hurt/Death clips. Those states keep the existing fallback presentation until compatible animations are added.

## Physical acceptance required

- Install the signed APK on real Android hardware.
- Validate Solo Campaign and Horde.
- Validate Dúo, then 3-player, then 4-player Squad over the public dedicated-server path.
- Test both Wi-Fi and mobile data.
- Record FPS, 1% low, memory and thermal behavior for Smooth/Standard/Ultra where practical.
- Do not mark beta.4 accepted solely from headless/VPS gates.

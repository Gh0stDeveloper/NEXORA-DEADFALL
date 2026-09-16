# NEXORA: DEADFALL 0.9.0-beta.5

Closed-beta lifecycle and recovery release.

## Build identity

- App version: `0.9.0-beta.5`
- Version code: `900005`
- Channel: `closed_beta`
- Network protocol: `2`
- Content version: `1`
- Minimum compatible client/server version code: `900005`
- Target Android API: `36`
- Maximum squad size: `4`

Beta.5 intentionally rejects beta.4 and older gameplay clients/servers because the orchestrated match lifecycle and reconnect semantics changed even though the protocol number remains `2`.

## Included

### Match reconnect/recovery

- Ticket-scoped reconnect for orchestrated dedicated matches.
- A reconnect can restore only the authoritative entity/state associated with the same private match ticket and admitted guest identity.
- Android reconnect flow is bounded to 42 seconds and 10 attempts.
- Authoritative player entity, slot, transform/gameplay snapshot, health/life state and weapon/loadout state are restored server-side.
- Clients do not upload trusted recovery HP, position, ammo or hit state.

### Dedicated match lifecycle

- Dedicated match heartbeat IPC every 2 seconds.
- Parent watchdog for stale heartbeat/live-but-frozen child processes.
- Startup timeout for never-started matches.
- Empty-session timeout after a match has previously admitted a player.
- Absolute match runtime TTL.
- Terminal child-process reaping.
- Monotonic lifecycle: after the first authoritative admission, `READY -> IN_MATCH` is preserved through temporary all-player reconnect gaps.

### Match results and lobby return

- Server-authoritative `VICTORY`, `DEFEAT` and `ABORTED` results.
- Result payload includes score, kills, wave and reason.
- Results are delivered to connected clients and mirrored to the parent through local IPC.
- Result screen supports automatic/manual return.
- Returning players re-enter a refreshed/unlocked squad lobby.

### Lifecycle telemetry

- Started/completed/defeated/aborted/failed/frozen/crashed/reaped/reconnect counters.
- Aggregate lifecycle health data through `/v1/health`.
- Public lifecycle health does not expose private tickets, guest identities, match IDs, PIDs or private file paths.

### Regression coverage

The real Linux child-process orchestration smoke covers:

- missing ticket rejection;
- first valid ticket admission;
- graceful ENet disconnect;
- same-ticket reconnect;
- same authoritative entity restoration;
- reconnect counter increment;
- second member admission;
- child-process cleanup.

## Carried forward from beta.4

- Lobby 2.0 presentation and normalized animated GLB previews.
- Central operator stage and turntable.
- Shared imported-animation driver.
- `operator_02` safe generic animation fallback using `mixamo_com`.
- Quaternius Idle/Walk/Run/Crawl/Attack mappings.
- Authoritative rifle/pistol/machete loadout.
- Replicated finite ammo and zombie ammo pickups.
- Mobile HP/ammo/weapon HUD and sprint toggle.
- MTU-safe FastLZ snapshot transport with 900-byte chunks.
- Server-authoritative movement, damage, health, ammo, zombies and campaign progression.
- Game Over/Restart hardening.
- Day/night visuals.
- Android render scale/LOD/MSAA/FPS quality tiers and zombie visual-distance culling.
- Reproducible Android generated-template sanitization for redundant Manifest merger directives.

## Production deployment status

**VPS automated deployment is complete.**

Confirmed runtime deployment anchor:

```text
f402f1696c0438447d76236122a5d82101a94cc0
```

The full `--force` production path completed:

- validation gates;
- Android Release Gradle export;
- APK Signature Scheme v2 verification;
- exactly one signer;
- publication to `/var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk`;
- localhost API validation on `127.0.0.1:24562`;
- HTTPS API validation through Nginx.

The transient ADB message `cannot connect to daemon at tcp:5037` is expected when no Android device is attached to the VPS and is not itself a failed gate.

## Physical acceptance still required

Beta.5 is deployed but is **not yet fully physically accepted**.

Required real-device sequence:

1. Solo Android Campaign/Horde/gameplay smoke.
2. Duo over the public Internet.
3. Deliberate disconnect/reconnect within the 42-second window; verify same identity/entity/state restoration.
4. Complete/fail a match and verify authoritative result plus both clients returning to the same unlocked lobby.
5. Three-player test.
6. Four-player test including DOWNED/revive/death and load.
7. Wi-Fi/mobile-data coverage where practical.
8. FPS/RAM/thermal observations and compatibility-matrix entries.

Any physical blocker takes priority over unrelated feature work.

## Known asset limitations

- `operator_02` exposes only `mixamo_com`; separate player Idle/Walk/Run/Attack/Hurt/Death requires compatible clips/retargeting.
- Current Quaternius asset has verified Idle/Walk/Run/Crawl/Attack, but no separately verified Hurt/Death clips.

## Next planned product block

If physical beta.5 testing reveals no critical blocker, the next contained development block is the download portal/version-history upgrade documented in `docs/DOWNLOAD_PORTAL_PLAN.md`.

Voice chat remains outside beta.5.
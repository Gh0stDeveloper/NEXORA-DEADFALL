# Presentation redesign continuation — 2026-09-14

> Historical checkpoint, superseded on 2026-09-16 by
> [HANDOFF_TACTICAL_PRESENTATION.md](HANDOFF_TACTICAL_PRESENTATION.md).
> The workspace was recovered and the redesigned source/assets are now included.
> The limitations below describe the earlier checkpoint, not current validation.

## Request and source state

The user requested a substantial presentation upgrade for **Gh0stDeveloper/NEXORA-DEADFALL**: application boot/loading, verified guest account entry, a colorful tactical lobby inspired by Free Fire and Call of Duty, coordinated Duo/Squad staging, better operators/zombies/weapons, music and sound. The corrected repository name is authoritative.

Continue on `agent/bootstrap-deadfall`. PR #1 stays open and Draft. The base inspected for this checkpoint was `85de528101d17acd40d8e65d02ab541cdd28269a`.

This checkpoint contains a **limited recovery of access/loading fixes**, not the full visual redesign or an Android release.

## Changes included in this checkpoint

- Immediate HTTPRequest start failures now use the same operation-aware error path as asynchronous failures, so registration/challenge/verification emit `login_failed` and the login screen exits its busy state.
- Session adoption rejects missing/empty tokens, invalid or expired expiry values, malformed account records and records belonging to another guest before reporting success. Invalid responses do not partially replace an existing session.
- Login status reflects registration, challenge and verification. A taken or invalid username returns to the existing editable input. Automatic recovery of an unknown guest is limited to one registration attempt per user-initiated login flow.
- The loading animation advances using elapsed time. Starting another load resets the visible progress and return action. Player-facing loading text no longer prints the server endpoint.
- `scripts/ci/login_loading_recovery_smoke.gd` exercises synchronous request failures, retry, malformed/valid session responses, login recovery, name editing, elapsed-time progress at 30/60/120 FPS, stage ordering, explicit completion and retry reset.
- The existing strict gameplay compile gate runs that child regression, checks its exit code, script errors and success marker.

## Verification status

**The reconstructed files in this checkpoint have not been run in Godot or exported to Android.** They received source review only. The selected execution environment became unavailable before the earlier visual work was uploaded. A previous local compile result does not validate this reconstructed commit.

The last inspected CI run for the base commit was `34592573587`. Its jobs had empty step arrays and no runner assigned. Those results provide no source-test evidence. Repository documentation already records an Actions billing/spending issue; consult actual job output when a new run starts rather than assuming the source failed.

When a Godot environment is available, run:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script scripts/ci/login_loading_recovery_smoke.gd
godot --headless --path . --script scripts/ci/gameplay_compile_smoke.gd
```

Use Godot 4.6.3 and the repository's required-model synchronization workflow for full import/gates. The new regression deliberately uses a relative URL to provoke a synchronous HTTPRequest failure without contacting a server; an invalid-URL engine diagnostic is expected for that fixture. It never creates or persists an account: it temporarily assigns and restores an in-memory guest fixture. Only the headless invocation is supported.

## Earlier local redesign — recovery required

The following work had been implemented in the previous local workspace but **was not uploaded to this branch** and is not included here:

- Tactical amber/cyan theme and an original quarantine-hangar background.
- Lightweight threaded boot scene and redesigned account-entry layout.
- Shared 3D lineup viewport for Solo/Duo/Squad, vacancies, operator selection, rotating weapon inspection and audio/settings dialogs.
- Articulated procedural operators and zombie archetypes; detailed rifle, pistol and machete geometry with first-person presentation.
- Music, ambient audio, UI/weapon/footstep/zombie cues, audio buses and persistent volume controls.
- Changes linking presentation to existing authoritative gameplay and replicated actions.

The remembered workspace was `/workspace/scratch/dd56f684c4c7/NEXORA-DEADFALL`; its availability has **not** been confirmed after the environment disconnected. Related visual captures/tools were under `/workspace/scratch/dd56f684c4c7/tools`. Check for that work before rebuilding it. Its local Git baseline was a connector-generated snapshot, not the upstream history; preserve the actual upstream branch ancestry when publishing.

The remembered generated artwork path was `/workspace/scratch/dd56f684c4c7/generated_images/exec-13a42681-3ca2-4ccf-a67a-7c52e6f3459f.png`. It depicted an original military quarantine hangar with a ruined city at amber sunrise, teal practical lighting, empty foreground, and no text or characters. It had been converted to `assets/ui/quarantine_hangar.webp` for the game. Neither asset is part of this checkpoint.

Visual checks in that workspace identified unfinished polish: beveled mesh normals/roughness, a scarf that looked spherical, weapon grip alignment, armory zoom, Squad framing and the ping overlay overlapping Chat. Also review stationary prone pose, initial audio volume and hidden viewport processing before publishing the recovered design.

## Next work

1. Recover the execution workspace and compare its files against the updated branch; integrate these access/loading fixes without discarding the larger local redesign.
2. Finish the visual issues above and inspect the actual boot path, account flow, Solo/Duo/Squad, operator selection, arsenal, settings, combat and reconnect/result return.
3. Run the strict compile/regression gates; inspect real renders at landscape phone sizes. Check audio clipping, looping and volume persistence.
4. Upload the completed source/assets on the existing branch and keep PR #1 Draft.
5. Export/validate a new Android build deliberately, then perform the physical Solo → Duo → three/four player acceptance described in `HANDOFF_BETA_5.md`. Do not describe an untested visual checkpoint as a professional finished release.

Preserve dedicated-server authority, private admission tickets, the existing match lifecycle and persistent signing identity. The production runtime remains the documented beta.5 anchor `f402f1696c0438447d76236122a5d82101a94cc0`; this checkpoint does not bump the beta version or imply a production deployment.

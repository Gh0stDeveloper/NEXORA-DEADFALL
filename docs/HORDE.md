# Offline Horde Vertical Slice

## Goal

Phase 5 turns the combat TestRange into an authority-driven offline Horde loop. The director schedules waves, selects zombie archetypes, enforces a quality-tier population budget, awards score/kills, enters game over on player death, and resets the run without bypassing the existing combat/health authority model.

## Lifecycle

`HordeDirector` uses explicit states:

`DISABLED -> COUNTDOWN -> SPAWNING -> ACTIVE -> INTERMISSION -> SPAWNING ... -> GAME_OVER`

- `COUNTDOWN`: initial start timer.
- `SPAWNING`: scheduled wave enemies are admitted only while population budget is available.
- `ACTIVE`: all scheduled enemies have spawned; the wave waits for remaining active zombies to die.
- `INTERMISSION`: short countdown before the next wave.
- `GAME_OVER`: player Health reached zero; new spawns stop until restart.

A wave completes only when `wave_spawned == wave_total_enemies` and the active-zombie registry is empty.

## Wave growth

Default wave size:

`6 + (wave - 1) * 3 + milestone_bonus`

Every five completed wave steps add an additional four scheduled enemies. A large scheduled wave does not imply that all enemies exist simultaneously because active population remains budgeted.

## Population budgets

| Tier | Active population cost | Spawn-rate multiplier |
| --- | ---: | ---: |
| Smooth | 8 | 0.85x |
| Standard | 14 | 1.00x |
| Ultra | 20 | 1.15x |
| Ultra HD | 28 | 1.30x |

Population uses cost rather than raw node count. A Tank costs 3 points and a Screamer costs 2, while Walker/Runner/Crawler cost 1. The director selects only archetypes that fit the remaining budget.

## Archetypes

| Archetype | Unlock | Cost | Score | Identity |
| --- | ---: | ---: | ---: | --- |
| Walker | Wave 1 | 1 | 100 | Baseline balanced enemy |
| Runner | Wave 2 | 1 | 125 | Low health, high speed and fast melee |
| Crawler | Wave 3 | 1 | 150 | Starts in crawler locomotion |
| Tank | Wave 4 | 3 | 350 | High health, slow, heavy melee and stronger limb thresholds |
| Screamer | Wave 5 | 2 | 250 | Buffs nearby zombies with temporary movement/damage rage |

Each zombie receives a private runtime duplicate of its `ZombieData`. Temporary Screamer rage therefore cannot mutate the shared `.tres` resource or accidentally buff every zombie of the same type globally.

## Screamer support behavior

When a Screamer is actively chasing/attacking and its cooldown expires, nearby zombies receive a temporary multiplier to `move_speed` and `attack_damage`. Buffs are restored to the instance's original values when the timer expires. The mechanic runs only where the zombie has simulation authority.

## Native Crawler

The native Crawler uses the same Phase 4 crawler locomotion path used when a normal zombie loses a leg. This avoids a second movement implementation and keeps crawler collision/navigation behavior consistent.

## Spawning

The TestRange provides seven peripheral spawn markers. The director first filters points outside `spawn_safety_radius` from the player; it falls back to all available markers only if no safe marker exists.

The active registry stores each zombie's node, population cost, score value and archetype ID. Death removes the registry entry before awarding score, so duplicate death callbacks cannot award twice.

## Score and run state

- Per-zombie score comes from `ZombieData.score_value`.
- Wave completion grants a deterministic completion bonus.
- `kills` increments once per registered zombie death.
- Player `HealthComponent.died` immediately transitions Horde to `GAME_OVER`.
- Restart clears the active registry/container, resets player health and returns counters to zero before the initial countdown.

## HUD

`HordeHUD` is safe-area aware and shows:

- wave;
- score;
- kills;
- enemies remaining;
- active population cost/current budget;
- start/intermission countdown;
- game-over summary and Restart button.

## Android telemetry

Android debug diagnostics now include a Horde snapshot in `DEADFALL_ANDROID_READY` and later emit `DEADFALL_HORDE_STATS` with state, wave, score, kills, active enemies and population budget. The Android runtime smoke requires those markers.

## Automated coverage

`scripts/ci/horde_smoke.gd` validates:

- wave growth and milestone formula;
- all four quality population budgets;
- progressive archetype unlocks;
- player-distance spawn safety;
- population-cost enforcement;
- score/kill single-award semantics;
- player death -> GAME_OVER;
- restart state and player health reset;
- fully-spawned/empty wave -> INTERMISSION;
- Screamer rage affects a nearby zombie without mutating shared Walker data;
- native Crawler uses crawler locomotion.

## Remaining validation

The implementation is complete at code level. Physical Android population/performance profiling and current-head Godot/Docker/Android workflow execution remain acceptance gates while the GitHub-hosted runner billing/spending block is unresolved.

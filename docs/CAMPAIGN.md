# Campaign vertical slice

Phase 8 adds a data-driven campaign layer on top of the existing authoritative combat, zombie, Horde and Squad systems.

## Authority

Campaign progression is authoritative. Local sessions can advance and persist progression. Dedicated servers advance campaign state for the whole room. Network clients only receive replica snapshots through `CampaignNetworkBridge` and cannot start missions, report authoritative kills, complete objectives or write campaign checkpoints.

The campaign does not create a second combat model. Confirmed Horde kills feed the mission director after the existing damage/health pipeline resolves them.

## Objective framework

`CampaignObjectiveData` supports:

- `REACH`: at least one recoverable squad member enters the target radius.
- `KILL`: counts only authoritative Horde kill events.
- `SURVIVE`: advances authoritative elapsed time while at least one player remains recoverable.
- `INTERACT`: requires a player to remain near a named target while holding the existing sanitized `interact` intent.
- `EXTRACT`: shared squad extraction trigger using an authoritative target radius.

Objectives are sequential and shared by the squad.

## Missions

### Mission 01 — First Signal

1. Reach the quarantine gate.
2. Eliminate 8 infected.
3. Hold the street for 18 seconds.
4. Reach extraction.

### Mission 02 — Last Broadcast

1. Reach the radio yard.
2. Restore the transmitter with a held interaction.
3. Eliminate 12 infected.
4. Keep the transmitter online for 22 seconds.
5. Escape through the service tunnel.

Both missions currently use the `OutbreakDistrict` vertical-slice environment. Final art can replace the placeholder geometry without changing mission data or objective authority.

## Checkpoints and persistence

Local campaign progress is stored under `user://campaign_<slot>.json` with a schema version, campaign ID, mission ID, objective index, checkpoint target and completion flag. A restored local mission teleports recoverable players to the saved checkpoint marker.

Dedicated sessions do not write the local campaign file. Multiplayer mission state lives authoritatively in the current server process and is replicated to clients; account/cloud progression is intentionally deferred to a later persistence/backend phase.

## Networking

Campaign state is small and global, so it uses a separate ordered-unreliable RPC channel at 8 Hz rather than inflating the heavier player/zombie snapshot. The replicated payload contains mission, current objective, progress, required amount, state and checkpoint ID.

Campaign multiplayer uses the existing four-player ENet session. Start a campaign server/client with `--campaign`; `--mission=mission_02_last_broadcast` selects Mission 02.

## Validation

- `campaign_smoke.gd` covers both mission chains, checkpoint storage, scene contracts and client authority rejection.
- `campaign_integration.sh` runs a dedicated campaign server with four real ENet clients and requires Squad plus campaign snapshot markers.
- Android diagnostics report campaign state when the CampaignArena is active.

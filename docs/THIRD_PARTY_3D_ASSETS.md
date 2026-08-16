# Provisional third-party 3D assets

NEXORA: DEADFALL currently supports a provisional external-model pipeline sourced from:

`Gh0stDeveloper/Objetos3D`

The main game repository does not commit those `.glb` binaries. Production/VPS builds stage them before Godot import/export through `scripts/assets/sync_objetos3d.sh`.

## Current mapped assets

| Runtime ID | Canonical file | Source filename currently observed | Source attribution in filename |
|---|---|---|---|
| `operator_01` | `operator_01.glb` | `low poly survival character by Daren - WJiiE1qmRU.glb` | Daren |
| `operator_02` | `operator_02.glb` | `Animated Character Base by J-Toastie - AZzoJo1FBm.glb` | J-Toastie |
| zombie animated | `zombie_animated.glb` | `Animated Zombie by Quaternius - jkrEvQZb8J.glb` | Quaternius |
| zombie fallback/static | `zombie_static.glb` | `Zombie by cs_aaron - ftpTNkeqGWc.glb` | cs_aaron |

The repository snapshot inspected while implementing Phase 11.3 also contained ZIP source packages for these models. The build synchronization intentionally ignores those ZIP files and stages only runtime GLB assets.

## Structure/building asset

The user intends to provide a 3D structure/building through `Gh0stDeveloper/Objetos3D`. At the Phase 11.3 implementation checkpoint, the recursive repository tree available to the integration contained the character/zombie files listed above but did **not** yet expose a structure/building asset.

When it appears, add an explicit stable canonical mapping rather than depending on its original download filename.

## Runtime behavior

- Character IDs remain stable (`operator_01`, `operator_02`) even if provisional models are replaced later.
- Missing GLBs do not prevent scenes from loading; built-in fallback meshes remain available.
- The lobby preview and player replicas dynamically load the canonical character model when present.
- Intact zombies may display the provisional external zombie model.
- On damage/dismemberment, zombies fall back to the existing gore-ready segmented rig so hitboxes, wounds and limb destruction continue to match the authoritative gameplay system.

## Licensing/redistribution gate

Do **not** infer a redistribution/commercial-use license from the filenames, from the fact that a model is downloadable, or from its presence in the provisional repository.

Before a public/commercial release, record for every third-party model:

1. original source URL;
2. creator/author;
3. exact license name/version;
4. whether commercial use is allowed;
5. whether modification is allowed;
6. attribution text and placement requirements;
7. whether redistribution inside an APK/game build is allowed;
8. any share-alike or source-file obligations.

At the Phase 11.3 checkpoint, no repository-level license document for the whole `Objetos3D` collection was relied upon by the integration. Licensing must therefore be verified per original asset before these provisional files are treated as production-ready art.

The planned replacement with original DEADFALL models should keep the same runtime IDs/canonical paths where practical, which allows art replacement without changing accounts, selected-character IDs, matchmaking or saved gameplay references.

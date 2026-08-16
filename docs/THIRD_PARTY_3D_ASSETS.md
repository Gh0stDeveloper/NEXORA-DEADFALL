# Provisional third-party 3D assets

NEXORA: DEADFALL currently uses a provisional external-model collection sourced from:

`Gh0stDeveloper/Objetos3D`

## Repository integration

The model repository is now pinned directly inside `Gh0stDeveloper/NEXORA-DEADFALL` as the Git submodule:

`vendor/Objetos3D`

The pinned source commit at this checkpoint is:

`28ea7a10a18fbe05a91fb3d920678991fff4afef`

The main DEADFALL tree also tracks the four canonical runtime paths under `assets/external/objetos3d/` as symbolic links into the vendored model source:

- `operator_01.glb`
- `operator_02.glb`
- `zombie_animated.glb`
- `zombie_static.glb`

This replaces the previous design where the primary repository contained no model linkage and every build had to discover/clone `Objetos3D` independently.

`scripts/assets/sync_objetos3d.sh` now prefers the pinned `vendor/Objetos3D` checkout. It validates every required source as a complete GLB 2.0 container before staging the canonical runtime models. If the submodule has not been initialized yet, the script first attempts `git submodule update`; an authenticated clone remains only as a compatibility fallback.

## VPS behavior

The production VPS already authenticates GitHub through the `deadfall` service account configured by the installer. `deploy/vps/update.sh --initial` and `--force` therefore:

1. update the DEADFALL branch;
2. synchronize and initialize `vendor/Objetos3D`;
3. stage the four canonical GLB runtime files;
4. validate their GLB headers and lengths;
5. let Godot import them;
6. run the Phase 11 model/runtime smoke before Android export and server restart.

A change to `.gitmodules` or `vendor/Objetos3D` is considered an app/server change by the differential updater, so moving the submodule to a newer model commit triggers the required import/build path.

## GitHub Actions access

`Gh0stDeveloper/Objetos3D` is private. A `GITHUB_TOKEN` issued only for `Gh0stDeveloper/NEXORA-DEADFALL` must not be assumed to have cross-repository read access.

When a GitHub Actions checkout has not already initialized the private submodule, the workflows use:

`DEADFALL_MODELS_TOKEN`

Use a fine-grained token with read-only Contents access to `Gh0stDeveloper/Objetos3D`. If a runner already has the vendored submodule populated, `scripts/ci/sync_required_models.sh` does not require a separate token just to restage the models.

The VPS path does not require this Actions secret because its existing `gh auth`/Git credential helper is used for private repository access.

## Current mapped assets

| Runtime ID | Canonical file | Vendored source filename | Source attribution in filename |
|---|---|---|---|
| `operator_01` | `operator_01.glb` | `low poly survival character by Daren - WJiiE1qmRU.glb` | Daren |
| `operator_02` | `operator_02.glb` | `Animated Character Base by J-Toastie - AZzoJo1FBm.glb` | J-Toastie |
| zombie animated | `zombie_animated.glb` | `Animated Zombie by Quaternius - jkrEvQZb8J.glb` | Quaternius |
| zombie fallback/static | `zombie_static.glb` | `Zombie by cs_aaron - ftpTNkeqGWc.glb` | cs_aaron |

The vendored source snapshot also contains ZIP packages for these models. ZIP files remain source/archive material only and are not copied into the Godot runtime path.

## Structure/building asset

The user intends to provide a 3D structure/building through `Gh0stDeveloper/Objetos3D`. At this checkpoint the pinned repository still contains only the four GLB files listed above and no structure/building asset.

When a structure appears, update the `vendor/Objetos3D` gitlink to the new reviewed source commit and add an explicit stable canonical mapping rather than depending on its original download filename.

## Runtime behavior

- Character IDs remain stable (`operator_01`, `operator_02`) even if provisional models are replaced later.
- Missing/invalid runtime models fail the Phase 11.3 production staging/smoke path rather than silently publishing a release without the expected four assets.
- The lobby preview and player replicas dynamically load the canonical character model.
- Intact zombies may display the provisional external zombie model.
- On damage/dismemberment, zombies fall back to the existing gore-ready segmented rig so hitboxes, wounds and limb destruction continue to match the authoritative gameplay system.

## Licensing/redistribution gate

Do **not** infer a redistribution/commercial-use license from the filenames, from the fact that a model is downloadable, from its presence in `Objetos3D`, or from the fact that DEADFALL now pins that repository as a submodule.

Before a public/commercial release, record for every third-party model:

1. original source URL;
2. creator/author;
3. exact license name/version;
4. whether commercial use is allowed;
5. whether modification is allowed;
6. attribution text and placement requirements;
7. whether redistribution inside an APK/game build is allowed;
8. any share-alike or source-file obligations.

At this checkpoint no repository-level license document for the whole `Objetos3D` collection is being treated as sufficient proof of redistribution rights. Licensing must therefore be verified per original asset before these provisional files are treated as production-ready art.

The planned replacement with original DEADFALL models should keep the same runtime IDs/canonical paths where practical, allowing art replacement without changing accounts, selected-character IDs, matchmaking or saved gameplay references.

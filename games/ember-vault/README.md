# Ember Vault

An original Hades-inspired low-poly dungeon using a locally supplied POLYGON Dungeon pack. Three connected chambers sit above animated lava: the Cinder Atrium, Hall of the Forgotten, and Ember Throne. Warm braziers contrast with turquoise gateway flames; walls use a cutaway layout for the angled camera.

The supplied female knight carries the pack's straight sword. Nine skeleton guardians protect the route. Defeat them, claim nine seals, and reach the statue at the far end of the third chamber. Five vitality points, a rechargeable dash, pause, defeat, victory, and restart are implemented.

## Run locally

Requires Godot **4.5.1+** and a licensed local copy of `POLYGON_Dungeon_Godot_4_5_1_v1_0_1.zip`.

From the repository root on Windows:

```powershell
.\Prepare-EmberVault.ps1
.\Play-EmberVault.ps1
```

Assets are already prepared in the development workspace. Alternatively open `project.godot` in Godot 4.5.1+, allow imports to complete, and press F5. No AI model is needed to play this authored sample.

| Controls | Action |
| --- | --- |
| WASD / arrows | Move relative to the camera |
| Left mouse / J / F | Sword attack |
| Space / Shift | Dash |
| Mouse wheel | Zoom |
| Escape | Pause / resume |
| R | Restart |

Attacks hit guardians within three units in all directions. This prototype uses procedural skeleton posing because these character prefabs provide no locomotion clips. It has basic pursuit AI rather than navigation or polished animation. No audio is implemented yet. The particle pack is not required; flames use custom procedural particles.

## Edit the map

`dungeon.gd` assembles the level from the pack's prefabs. To create a standalone, editable architecture scene, run:

```sh
godot --path games/ember-vault -- --bake
```

Then open `dungeon_layout.tscn` in the Godot editor. It contains the three rooms, bridges, floor tiles, walls, props, particles, and lava. Actors, gameplay UI, camera, and global lighting are owned by the playable main scene. The baked scene is a snapshot: edits to it do not change the runtime builder. To change the playable map, edit `build_map()` and `build_room()`.

## Verification

```sh
godot --path games/ember-vault --quit-after 600 -- --smoke-test
godot --path games/ember-vault --quit-after 600 -- --capture
```

The smoke test checks asset loading, sword attachment, movement, dashing, combat, and the victory trigger. Capture mode writes room/character previews to the ignored repository `generated/previews` directory. Use a graphical renderer for screenshot capture.

## Asset boundaries

Project scripts and shaders are GPL-3.0-only; see the repository LICENSE. The purchased pack is separately licensed by its supplier and is **not** covered by the project's GPL license. `Models/`, this project's `Assets/`, and baked layout snapshots are ignored by Git. No purchased source models or textures are included in the public repository. Each developer must provide their own authorized asset copy to run this sample.

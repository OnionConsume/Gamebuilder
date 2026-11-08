# Ember Vault

An original Hades-inspired low-poly dungeon using a locally supplied POLYGON Dungeon pack. Three connected chambers sit above animated lava: the Cinder Atrium, Hall of the Forgotten, and Ember Throne. Warm braziers contrast with turquoise gateway flames; walls use a cutaway layout for the angled camera.

The player carries the pack's straight sword. If `Assets/worker.glb` is installed, the player uses the supplied worker with Mixamo Idle, Walking, and Running clips. Otherwise the original dungeon knight is used. Nine skeleton guardians protect the route. Defeat them, claim nine seals, and reach the statue at the far end of the third chamber. Five vitality points, a rechargeable dash, pause, defeat, victory, and restart are implemented.

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
| Ctrl + movement | Walk using the Mixamo Walking clip |
| Left mouse / J / F | Sword attack |
| Space / Shift | Dash |
| Mouse wheel | Zoom |
| Escape | Pause / resume |
| R | Restart |

Attacks hit guardians within three units in all directions. Sword attacks use a custom arm pose layered over the Mixamo animation, with a 0.13-second wind-up before the hit and a short recovery. Hip translation stays in place so animation cannot move the mesh away from its collider. Original dungeon characters retain procedural posing as a fallback. It has basic pursuit AI rather than navigation or polished animation. No audio is implemented yet. The particle pack is not required; flames use custom procedural particles.

### Install the supplied Mixamo character

```powershell
.\Install-EmberVaultCharacter.ps1 -ModelPath 'C:/path/to/animated-character.glb'
```

The current integration expects the supplied model's `RightArm`, `RightForeArm`, `RightHand`, and `Hips` bones plus the exact clip names above; it is not a universal retargeter. Keep the GLB local. Godot must import it before the launcher can load it. Movement uses Mixamo clips embedded in that file, without downloading additional clips from Mixamo.

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
godot --path games/ember-vault --quit-after 3000 -- --physics-test
godot --path games/ember-vault --quit-after 1800 -- --animation-test
```

The smoke test checks asset loading, sword attachment, movement, dashing, combat, and the victory trigger. Capture mode writes room/character previews to the ignored repository `generated/previews` directory. Use a graphical renderer for screenshot capture.

The physics regression check verifies stable floor contact while idle and while walking/dashing through all chambers, both bridges, and their seams. Imported characters are visual-only skeleton hierarchies; the player controller owns the single capsule collider. This avoids nested prefab physics bodies pushing the controller upward.

With the worker GLB installed, the animation check verifies idle/run/walk transitions, in-place hip motion, sword movement, impact timing, and recovery. It saves local idle/swing previews in `generated/previews`.

## Asset boundaries

Project scripts and shaders are GPL-3.0-only; see the repository LICENSE. The purchased pack is separately licensed by its supplier and is **not** covered by the project's GPL license. `Models/`, this project's `Assets/`, and baked layout snapshots are ignored by Git. No purchased source models or textures are included in the public repository. Each developer must provide their own authorized asset copy to run this sample.

# Gamewright

Bring your assets. Describe your game. Get an editable Godot prototype.

An early AI game-building tool for solo developers and small teams. The first vertical slice generates a third-person crystal-collection arena from a natural-language description, optionally using your animated character model.

**Status:** working starter generator, not a general-purpose game creator. The AI chooses a validated game plan; tested templates generate the project. It does not yet create arbitrary mechanics, inspect skeleton compatibility, or autonomously playtest games.

## Quick start

Requirements: Node.js 22+ and Godot 4.x (Compatibility renderer). No npm dependencies.

```sh
npm run demo
```

Open `generated/demo/project.godot` in Godot, let imports finish, and press F5. Move with WASD or arrows, jump with Space, collect the crystals, and restart with R. Falling off the arena resets the character.

## Generate with AI

Install and start Ollama, then download a model:

```sh
ollama pull qwen2.5:7b
node src/cli.mjs --prompt "A quiet moon garden with 18 crystals and low jumps" --out generated/moon
```

Ollama runs locally at `http://127.0.0.1:11434`. Change the model with `--model` or the server with `--endpoint`. The description is sent to that endpoint; asset bytes stay local. Generation fails clearly if the server is unavailable or its plan is invalid; it does not silently substitute a demo.

## Bring a character

```sh
node src/cli.mjs --demo --character "C:/Assets/knight.glb" --out generated/knight
```

Use a self-contained GLB with embedded textures and animations, in meters, with the feet at the origin and the character facing -Z. Clips with `idle`, `walk`, `run`, or `jump` in their names are mapped automatically using AnimationPlayer. Other clips are preserved in the model but unused. Skeleton retargeting, root motion, automatic scale correction, separate animation files, and FBX import are not implemented. Without a model, a capsule placeholder is used.

Each output is a standalone project containing `project.godot`, the main scene, character/game scripts, copied assets, and `game-plan.json`. Existing output directories are never overwritten. Edit the generated scripts in Godot; generating again uses a new directory.

### Inspect assets before generating

```sh
node src/cli.mjs --inspect "C:/Assets/knight.glb"
```

Reports the content SHA-256, mesh count, skins and joint counts, animation names, suggested action mappings, and available mesh-local bounds. Bounds come from accessor metadata and do not include node transforms or animated poses. This is metadata inspection, not full glTF conformance validation or a guarantee of Godot compatibility.

Generation now checks GLB headers and chunk lengths and rejects external buffer/image dependencies before creating an output project. A supplied character produces `asset-manifest.json` in the output. Animation names in the report are suggestions; Godot may rename clips on import. No retargeting or automatic scaling is performed.

## Development

```sh
npm test
node src/cli.mjs --help
```

Tests cover plan validation, AI response handling, project generation, asset copying, and overwrite protection. A Godot installation is required to verify engine parsing and gameplay; Node tests alone do not verify those.

## Next milestones

1. Asset inspection: geometry bounds, skeletons, animation discovery, and a mapping preview.
2. Desktop workspace: asset library, prompt chat, project history, and embedded play preview.
3. More gameplay systems: melee combat, enemies, health, and wave progression.
4. Iteration: update a validated plan and preview changes without losing hand-edited work.
5. Verification: headless Godot import checks and controlled playtest sessions.

See [architecture](docs/architecture.md) for the implementation boundary.

## License

Gamewright is licensed under [GNU GPL version 3](LICENSE) (`GPL-3.0-only`). Generated projects include GPL-licensed runtime scripts from this repository and a copy of the license. Supplied models, textures, animations, and sounds retain their own licenses; they are not relicensed by importing them.

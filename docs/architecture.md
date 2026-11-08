# Architecture and product scope

Gamewright helps one developer reach a playable first version while retaining an ordinary editable engine project.

## Current pipeline

CLI prompt → local Ollama planner → strict plan validation → Godot templates → standalone project.

`src/assets.mjs` inspects self-contained GLB metadata before generation. The exported asset manifest records a content hash, animations, skins, suggested mappings, and available local geometry bounds. It checks container structure and external dependencies; full binary/accessor validation and world-space geometry inspection remain future work.

`src/plan.mjs` is the AI boundary. It accepts only bounded gameplay parameters and text, discards unknown fields, and never executes returned code. `src/godot.mjs` owns engine code and file layout. Generated projects have no runtime AI dependency. `src/cli.mjs` connects the two with explicit demo and AI modes.

Only a collectible arena is currently supported. Prompts requesting other genres are adapted into that constraint; they do not implement those genres. The plan description records intent but does not add executable mechanics. Output uses fixed collision dimensions and a fixed camera.

## Proposed next design

An asset manifest should record file hashes, dimensions, skeleton names, animation clips, and user-confirmed roles. A versioned game specification should reference assets by ID, map actions to clips, and choose supported gameplay modules. Keep AI planning separate from engine adapters so future Unity support does not require changing the product model.

Use generation snapshots and patches for iteration, with explicit handling for conflicts in user-edited files. Capture engine import and launch output before calling a generation successful. Exported desktop builds require Godot export templates and platform presets, which this starter does not install or generate.

## Acceptance criteria for the next vertical slice

- Import a real animated GLB and show its dimensions and clip list.
- Let the developer confirm scale, forward direction, and animation roles.
- Generate and launch a scene with grounded movement and mapped animations.
- Surface engine errors with a useful recovery path.
- Preserve the original assets and allow opening the project directly in Godot.

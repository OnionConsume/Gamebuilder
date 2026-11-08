# Crystal Rush

A complete playable test game for Gamewright, authored as a reference for the generator's next gameplay modules. It is a bespoke sample, not output that the current prompt generator can reproduce.

## Play

Open `project.godot` in Godot 4.3 or later and press F5. No downloaded assets, AI model, or npm packages are needed.

On Windows, run `./Play-CrystalRush.ps1` from the repository root to launch using Godot on PATH or the local portable engine downloaded during development.

Recover all twelve green crystals, then return to the central ring. Five red sentinels pursue you and speed up as you collect crystals. You have three shields. Dash through sentinels to destroy them; a dash recharges in 1.2 seconds. Damage gives brief invulnerability.

| Control | Action |
| --- | --- |
| WASD / arrows | Move |
| Space | Jump |
| Shift | Dash in your last movement direction |
| Escape | Pause / resume |
| R | Restart |

Includes a title screen, HUD, pause menu, victory and defeat screens, and replay. All geometry and materials are procedural placeholders. There is no sound yet.

## Engine verification

```sh
godot --headless --path games/crystal-rush --editor --import --quit
godot --headless --path games/crystal-rush --quit-after 600 -- --smoke-test
```

Run from the repository root. The smoke test verifies movement, dash cooldown, collection, extraction victory, defeat, and restarting. Success prints `CRYSTAL_RUSH_SMOKE_OK`. Godot 4.3's headless dummy renderer may report mesh-storage diagnostics; use a graphical run to check rendering.

Generate title/gameplay screenshots with `godot --path games/crystal-rush -- --capture`. They are saved in the repository's ignored `generated/previews` directory.

Licensed under GPL-3.0-only; see the bundled `LICENSE`.

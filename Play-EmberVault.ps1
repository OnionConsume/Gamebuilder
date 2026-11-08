# SPDX-License-Identifier: GPL-3.0-only
$ErrorActionPreference = 'Stop'
$emberProject = Join-Path $PSScriptRoot 'games/ember-vault'
if (-not (Test-Path -LiteralPath (Join-Path $emberProject 'Assets/PolygonDungeon'))) {
    & (Join-Path $PSScriptRoot 'Prepare-EmberVault.ps1')
}
$emberEngine = Join-Path $PSScriptRoot 'generated/tools/godot451/Godot_v4.5.1-stable_win64.exe'
if (-not (Test-Path -LiteralPath $emberEngine)) {
    $emberCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $emberCommand) { throw 'Install Godot 4.5.1+ or open games/ember-vault/project.godot in that editor.' }
    $emberEngine = $emberCommand.Source
}
& $emberEngine --path $emberProject

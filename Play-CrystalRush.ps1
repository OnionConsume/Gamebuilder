# SPDX-License-Identifier: GPL-3.0-only
$ErrorActionPreference = 'Stop'
$gamewrightEngine = Join-Path $PSScriptRoot 'generated/tools/godot/Godot_v4.3-stable_win64.exe'
$gamewrightProject = Join-Path $PSScriptRoot 'games/crystal-rush'
if (-not (Test-Path -LiteralPath $gamewrightEngine)) {
    $gamewrightCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gamewrightCommand) {
        throw 'Install Godot 4.3+ and add it to PATH, or open games/crystal-rush/project.godot in Godot.'
    }
    $gamewrightEngine = $gamewrightCommand.Source
}
Start-Process -FilePath $gamewrightEngine -ArgumentList @('--path', ('"' + $gamewrightProject + '"')) -WindowStyle Hidden

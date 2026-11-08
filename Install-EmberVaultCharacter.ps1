# SPDX-License-Identifier: GPL-3.0-only
param([Parameter(Mandatory = $true)][string]$ModelPath)
$ErrorActionPreference = 'Stop'
$emberSource = (Resolve-Path -LiteralPath $ModelPath).Path
if ([IO.Path]::GetExtension($emberSource).ToLowerInvariant() -ne '.glb') {
    throw 'Supply a GLB with the Mixamo skeleton and Idle, Walking, and Running animations.'
}
$emberAssetDirectory = Join-Path $PSScriptRoot 'games/ember-vault/Assets'
[IO.Directory]::CreateDirectory($emberAssetDirectory) | Out-Null
Copy-Item -LiteralPath $emberSource -Destination (Join-Path $emberAssetDirectory 'worker.glb') -Force
Write-Host 'Character installed locally. Open the project in Godot 4.5.1+ to import it before playing.'

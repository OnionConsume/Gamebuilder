# SPDX-License-Identifier: GPL-3.0-only
# Recreate local asset installation without publishing the paid asset pack.
param([string]$ArchivePath)
$ErrorActionPreference = 'Stop'
if (-not $ArchivePath) {
    $ArchivePath = Join-Path $PSScriptRoot 'Models/POLYGON_Dungeon_Godot_4_5_1_v1_0_1.zip'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$emberAssetRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'games/ember-vault/Assets'))
$emberPrefix = $emberAssetRoot + [IO.Path]::DirectorySeparatorChar
$emberArchive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ArchivePath))
$emberCount = 0
try {
    foreach ($emberEntry in $emberArchive.Entries) {
        if (-not $emberEntry.FullName.StartsWith('polygon_dungeon_01/Assets/')) { continue }
        $emberRelative = $emberEntry.FullName.Substring('polygon_dungeon_01/Assets/'.Length)
        if (-not $emberRelative -or $emberEntry.FullName.EndsWith('/')) { continue }
        $emberTarget = [IO.Path]::GetFullPath((Join-Path $emberAssetRoot $emberRelative))
        if (-not $emberTarget.StartsWith($emberPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Archive entry escapes the local Assets directory.'
        }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($emberTarget)) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($emberEntry, $emberTarget, $true)
        $emberCount++
    }
} finally { $emberArchive.Dispose() }
if (-not $emberCount) { throw 'No supported POLYGON Dungeon Assets folder was found in this archive.' }
Write-Host "Prepared $emberCount local asset files. Purchased assets remain ignored by Git."

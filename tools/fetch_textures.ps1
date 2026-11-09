#requires -Version 7.0
# Downloads the CC0 photoscanned texture sets used by the arena materials and keeps only the maps the
# shaders sample. Re-running is safe: sets already on disk are skipped unless -Force is given.
# -LedgerOnly rewrites the ambientCG rows of docs/license_ledger.csv from the files on disk
# (run it again after the editor import so the .import sidecars get their rows too).
param(
    [switch]$Force,
    [switch]$LedgerOnly
)
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Edition = "1K-JPG"
$Target = Join-Path $RepoRoot "assets/textures/ambientcg"
$Cache = Join-Path $RepoRoot "tools/out/texture_cache"
$Ledger = Join-Path $RepoRoot "docs/license_ledger.csv"

# Set id -> maps kept. Every set keeps Color, NormalGL and Roughness; the rest only where a shader reads them.
$Sets = [ordered]@{
    "Tiles093"   = @("Color", "NormalGL", "Roughness", "AmbientOcclusion", "Displacement")  # crypt floor
    "Bricks113A" = @("Color", "NormalGL", "Roughness", "AmbientOcclusion")                  # crypt walls (ashlar)
    "Rock058"    = @("Color", "NormalGL", "Roughness", "AmbientOcclusion")                  # pillars, ruins, plinth
    "Planks037A" = @("Color", "NormalGL", "Roughness", "AmbientOcclusion")                  # barrels, dummy post
    "Wood035"    = @("Color", "NormalGL", "Roughness")                                      # staff, bow, quiver
    "Metal021"   = @("Color", "NormalGL", "Roughness", "Metalness")                         # armour, sword, shields
    "Metal056C"  = @("Color", "NormalGL", "Roughness", "Metalness")                         # braziers, bands, blades
    "Fabric086"  = @("Color", "NormalGL", "Roughness")                                      # cloaks, hoods, rags
    "Carpet016"  = @("Color", "NormalGL", "Roughness", "AmbientOcclusion")                  # training-dummy burlap
    "Leather030" = @("Color", "NormalGL", "Roughness")                                      # belts, quiver, book
}


function Sync-Ledger {
    $today = Get-Date -Format "yyyy-MM-dd"
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in [System.IO.File]::ReadAllLines($Ledger)) {
        if (-not $line.StartsWith("acg_")) { $lines.Add($line) }
    }
    $files = Get-ChildItem -LiteralPath $Target -Recurse -File -Force | Sort-Object FullName
    foreach ($file in $files) {
        $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName).Replace("\", "/")
        $set = Split-Path -Leaf $file.DirectoryName
        $id = "acg_" + ($file.Name -replace '\.', '_').ToLowerInvariant()
        if ($file.Extension -eq ".import") {
            $lines.Add("$id,res://$rel,,Chronicle of Two project,Original work,,$($file.Name),,Godot import settings for the $set map,$today")
        } else {
            $lines.Add("$id,res://$rel,https://ambientcg.com/a/$set,ambientCG (Lennart Demes),CC0,$Edition,$($file.Name),,Unchanged; the pack's other maps and previews are not kept,$today")
        }
    }
    [System.IO.File]::WriteAllLines($Ledger, $lines)
    Write-Host "Ledger: $($files.Count) ambientCG rows."
}


if (-not $LedgerOnly) {
    New-Item -ItemType Directory -Force $Target, $Cache | Out-Null
    foreach ($set in $Sets.Keys) {
        $dest = Join-Path $Target $set
        $wanted = $Sets[$set] | ForEach-Object { "${set}_${Edition}_$_.jpg" }
        $missing = @($wanted | Where-Object { -not (Test-Path (Join-Path $dest $_)) })
        if ($missing.Count -eq 0 -and -not $Force) {
            Write-Host "$set already present"
            continue
        }
        $zip = Join-Path $Cache "${set}_$Edition.zip"
        if ($Force -or -not (Test-Path $zip)) {
            Write-Host "Downloading $set ($Edition)"
            Invoke-WebRequest -TimeoutSec 120 -Uri "https://ambientcg.com/get?file=${set}_$Edition.zip" -OutFile $zip
        }
        $unpacked = Join-Path $Cache "${set}_$Edition"
        if (Test-Path $unpacked) { Remove-Item -Recurse -Force $unpacked }
        Expand-Archive -LiteralPath $zip -DestinationPath $unpacked
        New-Item -ItemType Directory -Force $dest | Out-Null
        foreach ($name in $wanted) {
            $source = Join-Path $unpacked $name
            if (-not (Test-Path $source)) { throw "$set pack has no $name" }
            Copy-Item -LiteralPath $source -Destination (Join-Path $dest $name) -Force
        }
        Write-Host "$set -> $($wanted.Count) maps"
    }
}
Sync-Ledger

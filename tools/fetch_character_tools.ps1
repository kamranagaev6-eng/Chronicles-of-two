#requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$Confirmed
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Downloads = Join-Path $RepoRoot ".engine/blender/downloads"
$BlenderDir = Join-Path $RepoRoot ".engine/blender/blender-5.2.3-windows-x64"
$BlenderExe = Join-Path $BlenderDir "blender.exe"
$Portable = Join-Path $BlenderDir "portable"

$Pinned = @(
    @{
        Name = "blender-5.2.3-windows-x64.zip"
        Url = "https://download.blender.org/release/Blender5.2/blender-5.2.3-windows-x64.zip"
        Bytes = 405839452
        Sha256 = "723f08a4401502561eb763cdeacf8745b31e5f3f154d287d3830d97cf75dc2fb"
    },
    @{
        Name = "add-on-mpfb-v2.0.18.zip"
        Url = "https://extensions.blender.org/download/sha256:c075b3e9b94b8e5556a5f03f4653602d02ea306de08126e8f55ed6dee28a2dad/add-on-mpfb-v2.0.18.zip"
        Bytes = 45956992
        Sha256 = "c075b3e9b94b8e5556a5f03f4653602d02ea306de08126e8f55ed6dee28a2dad"
    },
    @{
        Name = "makehuman_system_assets_cc0.zip"
        Url = "https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip"
        Bytes = 280737770
        Sha256 = "b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107"
    }
)

if (-not (Test-Path $Downloads)) {
    New-Item -ItemType Directory -Path $Downloads -Force | Out-Null
}

$MissingOrMismatch = @()
foreach ($item in $Pinned) {
    $filePath = Join-Path $Downloads $item.Name
    if (Test-Path $filePath) {
        $hash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -eq $item.Sha256.ToLowerInvariant()) {
            Write-Host "verified $($item.Name)"
        } else {
            $MissingOrMismatch += $item
        }
    } else {
        $MissingOrMismatch += $item
    }
}

if ($MissingOrMismatch.Count -gt 0) {
    if (-not $Confirmed) {
        Write-Host "Batch of character tool downloads to confirm:"
        foreach ($m in $MissingOrMismatch) {
            Write-Host "  - $($m.Name) ($($m.Bytes) bytes) from $($m.Url)"
        }
        Write-Host "Ask the owner to confirm this download batch, then run again with -Confirmed."
        exit 2
    }
    foreach ($m in $MissingOrMismatch) {
        $filePath = Join-Path $Downloads $m.Name
        Write-Host "Downloading $($m.Name)..."
        Invoke-WebRequest -Uri $m.Url -OutFile $filePath
        $hash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $m.Sha256.ToLowerInvariant()) {
            Remove-Item $filePath -Force
            throw "SHA256 mismatch for $($m.Name): expected $($m.Sha256), got $hash"
        }
        Write-Host "verified $($m.Name)"
    }
}

# Unzip Blender if absent
if (-not (Test-Path $BlenderExe)) {
    Write-Host "Unzipping Blender 5.2.3..."
    $blenderZip = Join-Path $Downloads "blender-5.2.3-windows-x64.zip"
    Expand-Archive -Path $blenderZip -DestinationPath (Split-Path -Parent $BlenderDir) -Force
}

# Create portable directory if absent
if (-not (Test-Path $Portable)) {
    New-Item -ItemType Directory -Path $Portable -Force | Out-Null
}

# Install MPFB extension if absent
$mpfbDir = Join-Path $Portable "extensions/user_default/mpfb"
if (-not (Test-Path $mpfbDir)) {
    Write-Host "Installing MPFB 2.0.18..."
    $mpfbZip = Join-Path $Downloads "add-on-mpfb-v2.0.18.zip"
    & $BlenderExe --command extension install-file -r user_default -e $mpfbZip
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install MPFB extension (exit code $LASTEXITCODE)"
    }
}

# Install MakeHuman system assets pack if absent
$packJson = Join-Path $Portable "extensions/.user/user_default/mpfb/data/packs/makehuman_system_assets.json"
if (-not (Test-Path $packJson)) {
    Write-Host "Installing MakeHuman system assets pack..."
    $assetsZip = Join-Path $Downloads "makehuman_system_assets_cc0.zip"
    $installScript = Join-Path $RepoRoot "tools/characters/blender/install_packs.py"
    & $BlenderExe --background --python-exit-code 1 --python $installScript -- $assetsZip
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $packJson)) {
        throw "Failed to install MakeHuman system assets (exit code $LASTEXITCODE)"
    }
}

Write-Host "character tools ready: Blender 5.2.3, MPFB 2.0.18, makehuman_system_assets"

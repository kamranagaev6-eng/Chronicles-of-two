# Resolves the pinned Blender 5.2.3 binary. Dot-source this file: . "$PSScriptRoot/blender_path.ps1"
# Order: $env:BLENDER, then .engine/blender/blender-5.2.3-windows-x64/blender.exe
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:Blender = $null
if ($env:BLENDER -and (Test-Path $env:BLENDER)) {
    $script:Blender = $env:BLENDER
} elseif (Test-Path (Join-Path $script:RepoRoot ".engine/blender/blender-5.2.3-windows-x64/blender.exe")) {
    $script:Blender = Join-Path $script:RepoRoot ".engine/blender/blender-5.2.3-windows-x64/blender.exe"
}
if (-not $script:Blender) {
    throw "Blender 5.2.3 not found. Run ./tools/fetch_character_tools.ps1."
}

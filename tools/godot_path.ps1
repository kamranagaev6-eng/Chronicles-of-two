# Resolves the pinned Godot 4.7.2 console binary. Dot-source this file: . "$PSScriptRoot/godot_path.ps1"
# Order: $env:GODOT, then .engine/ in the repo, then godot on PATH.
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:Godot = $null
if ($env:GODOT -and (Test-Path $env:GODOT)) {
    $script:Godot = $env:GODOT
} elseif (Test-Path (Join-Path $script:RepoRoot ".engine/Godot_v4.7.2-stable_win64_console.exe")) {
    $script:Godot = Join-Path $script:RepoRoot ".engine/Godot_v4.7.2-stable_win64_console.exe"
} else {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $script:Godot = $cmd.Source }
}
if (-not $script:Godot) {
    throw "Godot 4.7.2 not found. Put Godot_v4.7.2-stable_win64(.exe/_console.exe) in .engine/ or set `$env:GODOT."
}
# The GUI binary (for windows you want to see) sits next to the console one.
$script:GodotGui = $script:Godot -replace '_console\.exe$', '.exe'

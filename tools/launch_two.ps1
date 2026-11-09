#requires -Version 7.0
# Opens a host window and a guest window side by side on this PC (separate profiles and saves).
# Add latency and loss with clumsy (https://jagt.github.io/clumsy/) to test 80 ms +/- 20 ms and 2% loss.
# Usage: ./tools/launch_two.ps1 [-Port 24680] [-HostClass vanguard] [-GuestClass riftweaver] [-Bot]
param(
    [int]$Port = 24680,
    [string]$HostClass = "vanguard",
    [string]$GuestClass = "riftweaver",
    [switch]$Bot
)
. "$PSScriptRoot/godot_path.ps1"
$extra = @()
if ($Bot) { $extra += "--bot" }
$common = @("--path", $RepoRoot, "--resolution", "960x540")
Start-Process -FilePath $GodotGui -ArgumentList ($common + @("--position", "0,40", "--", "--host", "--port=$Port", "--profile=local_host", "--class=$HostClass") + $extra)
Start-Sleep -Milliseconds 1500
Start-Process -FilePath $GodotGui -ArgumentList ($common + @("--position", "960,40", "--", "--join=127.0.0.1", "--port=$Port", "--profile=local_guest", "--class=$GuestClass") + $extra)
Write-Host "Host and guest windows started. Ready up in both lobbies; the host starts the arena."

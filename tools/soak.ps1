#requires -Version 7.0
# Unattended two-instance soak: a headless host and a headless guest, both played by the scripted bot,
# connected over loopback. Prints each side's [soak] report and any script errors.
# Usage: ./tools/soak.ps1 [-Seconds 60] [-Port 24711]
param(
    [ValidateRange(10, 7200)][int]$Seconds = 60,
    [int]$Port = 24711
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/godot_path.ps1"
$outputDir = Join-Path $RepoRoot "tools/out/soak"
New-Item -ItemType Directory -Force $outputDir | Out-Null
$runtime = Join-Path $outputDir ("runtime-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force "$runtime/roaming", "$runtime/local" | Out-Null

function Start-Instance([string]$Name, [string[]]$UserArgs) {
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Godot
    $info.WorkingDirectory = $RepoRoot
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.CreateNoWindow = $true
    $info.Environment["APPDATA"] = "$runtime/roaming"
    $info.Environment["LOCALAPPDATA"] = "$runtime/local"
    foreach ($a in @("--headless", "--path", $RepoRoot, "--")) { $info.ArgumentList.Add($a) }
    foreach ($a in $UserArgs) { $info.ArgumentList.Add($a) }
    $p = [System.Diagnostics.Process]::Start($info)
    return @{ Name = $Name; Process = $p; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync() }
}

$hostRun = Start-Instance "host" @("--host", "--bot", "--port=$Port", "--profile=soak_host", "--name=HostBot", "--class=vanguard", "--quit-after=$($Seconds + 4)")
Start-Sleep -Milliseconds 1500
$guestRun = Start-Instance "guest" @("--join=127.0.0.1", "--bot", "--port=$Port", "--profile=soak_guest", "--name=GuestBot", "--class=riftweaver", "--quit-after=$Seconds")

$failed = $false
foreach ($run in @($guestRun, $hostRun)) {
    if (-not $run.Process.WaitForExit(($Seconds + 60) * 1000)) {
        $run.Process.Kill($true)
        Write-Host "$($run.Name): timed out" -ForegroundColor Red
        $failed = $true
    }
    $log = $run.Out.GetAwaiter().GetResult() + $run.Err.GetAwaiter().GetResult()
    [System.IO.File]::WriteAllText((Join-Path $outputDir "$($run.Name).log"), $log)
    Write-Host "== $($run.Name) (exit $($run.Process.ExitCode))" -ForegroundColor Cyan
    $log -split "`n" | Where-Object { $_ -match '^\[soak\]|^\[net\]' } | ForEach-Object { Write-Host $_.TrimEnd() }
    $errors = @($log -split "`n" | Where-Object { $_ -match '^(SCRIPT ERROR|ERROR):' })
    if ($errors.Count -gt 0) {
        $failed = $true
        Write-Host "$($errors.Count) error line(s); first ones:" -ForegroundColor Red
        $errors | Select-Object -Unique | Select-Object -First 12 | ForEach-Object { Write-Host "  $($_.TrimEnd())" }
    }
}
Write-Host "Logs: $outputDir"
exit ([int]$failed)

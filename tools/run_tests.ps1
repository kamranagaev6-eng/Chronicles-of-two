#requires -Version 7.0
# Headless checks with isolated user data, bounded runtimes and fresh GUT evidence.
param(
    [switch]$NoImport,
    [string]$Filter = "",
    [switch]$AllowUnavailableCertificateStore,
    [ValidateRange(1, 3600)][int]$TimeoutSeconds = 180
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/godot_path.ps1"
$outputDir = Join-Path $RepoRoot "tools/out"
New-Item -ItemType Directory -Force $outputDir | Out-Null
[System.IO.File]::WriteAllText((Join-Path $outputDir ".gdignore"), "")
$runId = [guid]::NewGuid().ToString("N")
$runtimeDir = Join-Path $outputDir "runtime/$runId"
New-Item -ItemType Directory -Force "$runtimeDir/roaming", "$runtimeDir/local" | Out-Null
$failed = [System.Collections.Generic.List[string]]::new()

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$Arguments)
    Write-Host "== $Name" -ForegroundColor Cyan
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Godot
    $startInfo.WorkingDirectory = $RepoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    # Only the child engine sees these overrides; the parent shell is unchanged.
    $startInfo.Environment["APPDATA"] = "$runtimeDir/roaming"
    $startInfo.Environment["LOCALAPPDATA"] = "$runtimeDir/local"
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "Could not start Godot for $Name." }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $finished) {
            $process.Kill($true)
            $process.WaitForExit()
            $failed.Add("$Name (timed out)")
        }
        $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        [System.IO.File]::WriteAllText((Join-Path $runtimeDir "$Name.log"), $log)
        [System.IO.File]::WriteAllText((Join-Path $outputDir "$Name.log"), $log)
        Write-Host $log.TrimEnd()
        # Godot can report parse/import errors while returning zero.
        $diagnostics = $log
        if ($AllowUnavailableCertificateStore) {
            $diagnostics = $diagnostics -replace '(?m)^ERROR: Failed to read the root certificate store\.\r?$', ''
        }
        if ($process.ExitCode -ne 0 -or $diagnostics -match '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error|Compile Error):') {
            $failed.Add($Name)
        }
        return $log
    } finally {
        $process.Dispose()
    }
}

try {
    if ($AllowUnavailableCertificateStore) {
        Write-Host "Certificate-store access diagnostic explicitly allowed for this local run; TLS is not validated."
    }
    $versionText = Invoke-GodotCheck -Name "version" -Arguments @("--version")
    if ($versionText.Trim() -notmatch '^4\.7\.2\.stable\.') {
        throw "Expected Godot 4.7.2 stable; got '$($versionText.Trim())'."
    }
    foreach ($pin in @{ gut = "9.7.1"; netfox = "1.35.3"; "netfox.internals" = "1.35.3" }.GetEnumerator()) {
        $plugin = Get-Content -LiteralPath (Join-Path $RepoRoot "addons/$($pin.Key)/plugin.cfg") -Raw
        if ($plugin -notmatch ('(?m)^version\s*=\s*"' + [regex]::Escape($pin.Value) + '"\s*$')) {
            throw "Add-on $($pin.Key) must be pinned to $($pin.Value)."
        }
    }
    $common = @("--headless", "--path", $RepoRoot)
    if (-not $NoImport) {
        $null = Invoke-GodotCheck -Name "import" -Arguments ($common + @("--import"))
    }
    # A unique report prevents an old passing run from masking a startup failure.
    $junitPath = Join-Path $runtimeDir "junit.xml"
    $gutConfig = Get-Content -LiteralPath (Join-Path $RepoRoot ".gutconfig.json") -Raw | ConvertFrom-Json -AsHashtable
    $gutConfig["junit_xml_file"] = $junitPath
    $gutConfig["junit_xml_timestamp"] = $false
    $gutConfig["should_exit"] = $true
    $gutConfig["disable_colors"] = $true
    $gutConfigPath = Join-Path $runtimeDir "gutconfig.json"
    [System.IO.File]::WriteAllText($gutConfigPath, ($gutConfig | ConvertTo-Json -Depth 20))
    $gutArgs = $common + @("-s", "addons/gut/gut_cmdln.gd", "-gconfig=$gutConfigPath")
    if ($Filter) { $gutArgs += "-gselect=$Filter" }
    $null = Invoke-GodotCheck -Name "gut" -Arguments $gutArgs
    if (-not (Test-Path -LiteralPath $junitPath)) {
        $failed.Add("GUT report missing (tests did not finish)")
    } else {
        [xml]$report = Get-Content -LiteralPath $junitPath -Raw
        $cases = @($report.SelectNodes("//testcase"))
        $executedCases = @($report.SelectNodes("//testcase[not(skipped)]"))
        $failures = @($report.SelectNodes("//failure | //error"))
        if ($executedCases.Count -eq 0 -or $failures.Count -gt 0) { $failed.Add("GUT report") }
        Copy-Item -LiteralPath $junitPath -Destination (Join-Path $outputDir "junit.xml") -Force
        Write-Host "GUT report: $($cases.Count) tests, $($failures.Count) failures/errors."
    }
    $null = Invoke-GodotCheck -Name "data" -Arguments ($common + @("-s", "tools/validate_data.gd"))
    $null = Invoke-GodotCheck -Name "ledger" -Arguments ($common + @("-s", "tools/check_ledger.gd"))
} catch {
    $failed.Add($_.Exception.Message)
}

if ($failed.Count -gt 0) {
    Write-Host "FAILED: $(($failed | Select-Object -Unique) -join ', ')" -ForegroundColor Red
    Write-Host "Full logs for this run: $runtimeDir"
    exit 1
}
Write-Host "All checks passed. Logs for this run: $runtimeDir" -ForegroundColor Green
exit 0

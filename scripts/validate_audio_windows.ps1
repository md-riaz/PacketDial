<#
.SYNOPSIS
    Validate Windows audio playback using just_audio/just_audio_windows.

.DESCRIPTION
    Runs a minimal Flutter target that loads every file in assets/sounds
    from AssetManifest and attempts playback with just_audio.
    The process exits with:
      0 -> all assets passed
      1 -> one or more assets failed

.USAGE
    .\scripts\validate_audio_windows.ps1
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param($m) Write-Output "`n>>> $m" }

$repoRoot = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $repoRoot "app_flutter"

Write-Step "Ensuring Flutter dependencies"
Push-Location $appRoot
try {
    $reportPath = Join-Path $env:TEMP "packetdial_audio_validation_report.json"
    if (Test-Path $reportPath) {
        Remove-Item $reportPath -Force
    }

    flutter pub get

    Write-Step "Stopping running PacketDial instances"
    Stop-Process -Name "PacketDial" -Force -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Milliseconds 300

    Write-Step "Building just_audio Windows validation target"
    flutter build windows --release -t bin/audio_validation_main.dart

    if ($LASTEXITCODE -ne 0) {
        Write-Output "Audio validation build FAILED"
        exit $LASTEXITCODE
    }

    # Some local builds place app.so under .dart_tool/flutter_build/*/app.so.
    # Ensure the runner data directory has app.so before launching.
    $runnerDataDir = Join-Path $appRoot "build\windows\x64\runner\Release\data"
    if (!(Test-Path $runnerDataDir)) {
        New-Item -ItemType Directory -Path $runnerDataDir -Force | Out-Null
    }
    $runnerAppSo = Join-Path $runnerDataDir "app.so"
    $appSoCandidates = @(
        Get-ChildItem (Join-Path $appRoot ".dart_tool\flutter_build") -Recurse -File -Filter "app.so" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
    )
    if ($appSoCandidates -and $appSoCandidates.Count -gt 0) {
        Copy-Item $appSoCandidates[0].FullName $runnerAppSo -Force
        Write-Output "Copied app.so from $($appSoCandidates[0].FullName)"
    }

    $exePath = Join-Path $appRoot "build\windows\x64\runner\Release\PacketDial.exe"
    if (!(Test-Path $exePath)) {
        Write-Output "Audio validation executable not found: $exePath"
        exit 1
    }

    Write-Step "Running just_audio Windows validation executable"
    $process = Start-Process -FilePath $exePath -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Output "Audio validation runtime FAILED (exit=$($process.ExitCode))"
        exit $process.ExitCode
    }

    if (!(Test-Path $reportPath)) {
        Write-Output "Validation report not found: $reportPath"
        exit 1
    }

    $report = Get-Content $reportPath -Raw | ConvertFrom-Json
    Write-Output "Validation report: $reportPath"
    Write-Output "Result: $($report.success)"
    Write-Output "Summary: $($report.summary)"
    if (-not $report.success) {
        exit 1
    }
} finally {
    Pop-Location
}

Write-Output "`nAudio validation passed."

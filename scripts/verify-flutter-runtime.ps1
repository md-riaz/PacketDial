<#
.SYNOPSIS
    Verify that the Flutter Windows build output contains all required runtime files.

.DESCRIPTION
    Checks the Flutter Windows release directory for flutter_windows.dll,
    icudtl.dat, and the data/ directory. Exits with code 1 if any are missing.

    Usage:
        .\scripts\verify-flutter-runtime.ps1 [-ReleaseDir <path>]
#>

param(
    [string]$ReleaseDir = "app_flutter\build\windows\x64\runner\Release"
)

$ErrorActionPreference = 'Stop'

Write-Host "Contents of ${ReleaseDir}:"
Get-ChildItem $ReleaseDir -Recurse | ForEach-Object {
    Write-Host "  $($_.FullName)  ($([math]::Round($_.Length / 1KB, 1)) KB)"
}

$required = @('flutter_windows.dll', 'icudtl.dat')
foreach ($f in $required) {
    if (-not (Test-Path (Join-Path $ReleaseDir $f))) {
        Write-Error "FATAL: $f is missing from the build output."
        exit 1
    }
}
if (-not (Test-Path (Join-Path $ReleaseDir 'data'))) {
    Write-Error "FATAL: data/ directory is missing from the build output."
    exit 1
}
Write-Host "All required Flutter runtime files are present."

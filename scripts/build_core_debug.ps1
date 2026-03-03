<#
.SYNOPSIS
    Build Rust core in debug mode (optimized for fast iteration).

.DESCRIPTION
    Builds voip_core.dll in debug mode with minimal optimization.
    Compilation is ~5-10x faster than release mode, making it ideal
    for rapid development and testing with hot-reload.

    This script:
    1. Builds core_rust/ with cargo (debug mode, no --release flag)
    2. Verifies the DLL was created successfully

    The CMakeLists.txt post-build step automatically copies this DLL
    to Flutter's Debug output folder during `flutter run` or Flutter builds.

    Run from the repository root:
        .\scripts\build_core_debug.ps1

    Or let run_app.ps1 handle it automatically:
        .\scripts\run_app.ps1

.NOTES
    - Debug mode: ~30-60 seconds to compile
    - Release mode: ~1-3 minutes to compile
    - Output: core_rust\target\x86_64-pc-windows-msvc\debug\voip_core.dll
    - Use this for development (faster iterations)
    - Use build_core.ps1 for release artifacts and performance testing

.LINK
    See docs/dev-workflow.md for hot-reload development setup
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Color helpers for output
function Write-Step  { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }
function Write-OK    { param($m) Write-Host "    [OK]   $m" -ForegroundColor Green }
function Write-Info  { param($m) Write-Host "    [INFO] $m" -ForegroundColor Yellow }
function Write-Fail  { param($m) Write-Host "    [FAIL] $m" -ForegroundColor Red }

$RepoRoot = Split-Path -Parent $PSScriptRoot

Write-Step "Building Rust core (debug mode)"
Write-Info "This may take 30-60 seconds..."

Push-Location "$RepoRoot\core_rust"
try {
    cargo build --target x86_64-pc-windows-msvc
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Cargo build failed with exit code $LASTEXITCODE"
        exit 1
    }
} finally {
    Pop-Location
}

$DllPath = "$RepoRoot\core_rust\target\x86_64-pc-windows-msvc\debug\voip_core.dll"
if (Test-Path $DllPath) {
    $size = (Get-Item $DllPath).Length / 1KB
    Write-OK "voip_core.dll built successfully ($([math]::Round($size,1)) KB)"
    Write-OK "Location: $DllPath"
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "Ready for Flutter hot-reload development" -ForegroundColor Green
    Write-Host "Run: .\scripts\run_app.ps1" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
} else {
    Write-Fail "DLL not found at expected location: $DllPath"
    Write-Info "Check the cargo build output above for errors."
    exit 1
}

<#
.SYNOPSIS
    Automate the end-to-end release process for PacketDial.

.DESCRIPTION
    This script provides a single entry point for creating a distributable release.
    It performs the following steps in sequence:
    1. Builds the Rust core in Release mode.
    2. Builds the Flutter Windows application in Release mode.
    3. Packages the application into a distributable ZIP archive.

.USAGE
    .\scripts\build_dist.ps1

.OUTPUTS
    dist\PacketDial-windows-x64.zip
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Color helpers for output
function Write-Step { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }
function Write-OK { param($m) Write-Host "    [OK]   $m" -ForegroundColor Green }
function Write-Info { param($m) Write-Host "    [INFO] $m" -ForegroundColor Yellow }
function Write-Fail { param($m) Write-Host "    [FAIL] $m" -ForegroundColor Red }

$RepoRoot = Resolve-Path "."
$ScriptsDir = Join-Path $RepoRoot "scripts"

Write-Host "================================================" -ForegroundColor Magenta
Write-Host "   PacketDial End-to-End Build & Package        " -ForegroundColor Magenta
Write-Host "================================================" -ForegroundColor Magenta

# ── 1. Build Rust core (Release) ─────────────────────────────────────────────
Write-Step "Step 1: Building Rust Core (Release mode)"
& "$ScriptsDir\build_core.ps1" -Configuration Release
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Rust core build failed. Aborting."
    exit 1
}
Write-OK "Rust core built and DLL copied to runner directory."

# ── 2. Build Flutter App (Release) ───────────────────────────────────────────
Write-Step "Step 2: Building Flutter Windows Application (Release mode)"
Push-Location "app_flutter"
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Flutter build failed. Aborting."
        exit 1
    }
}
finally {
    Pop-Location
}
Write-OK "Flutter release build complete."

# ── 3. Package Application ───────────────────────────────────────────────────
Write-Step "Step 3: Packaging Application"
& "$ScriptsDir\package.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Packaging failed. Aborting."
    exit 1
}

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "   Build & Packaging Successful!                " -ForegroundColor Green
Write-Host "   Artifact: dist\PacketDial-windows-x64.zip    " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

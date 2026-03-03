<#
.SYNOPSIS
    Run PacketDial in debug mode with hot-reload support.

.DESCRIPTION
    This is the primary entry point for active development. The script:

    1. Builds Rust core in debug mode (fast, ~30-60 seconds)
    2. Copies voip_core.dll to Flutter's Debug output directory
    3. Launches Flutter with hot-reload enabled for immediate iteration

    Run from the repository root:
        .\scripts\run_app.ps1

    After the app launches, you can:
    - Edit Dart/Flutter code → hot-reload by pressing 'r' in the Flutter terminal
    - Edit Rust code → press 'R' in Flutter to hot-restart (Rust rebuilds + hot-reload)

.NOTES
    - Uses debug mode (faster compilation than release)
    - Automatically copies DLL before launching (even if CMake post-build step fails)
    - Kills any running PacketDial process before copying DLL (avoids lock issues)
    - Requires Flutter to be configured for Windows Desktop:
        flutter config --enable-windows-desktop

.LINK
    See docs/dev-workflow.md for detailed hot-reload workflow instructions
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Color helpers for output
function Write-Step  { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }
function Write-OK    { param($m) Write-Host "    [OK]   $m" -ForegroundColor Green }
function Write-Info  { param($m) Write-Host "    [INFO] $m" -ForegroundColor Yellow }
function Write-Warn  { param($m) Write-Host "    [WARN] $m" -ForegroundColor Yellow }
function Write-Fail  { param($m) Write-Host "    [FAIL] $m" -ForegroundColor Red }

$RepoRoot = Split-Path -Parent $PSScriptRoot

# ── 1. Build Rust core (stub DLL, no PJSIP required) ────────────────────────
Write-Step "Building Rust core (debug mode)"

& "$PSScriptRoot\build_core.ps1" -Configuration Debug
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Rust core build failed"
    exit 1
}
Write-OK "Rust core built"

# ── 2. Copy DLL to Flutter Debug output ─────────────────────────────────────
Write-Step "Preparing Flutter Debug environment"

$DebugOut = Join-Path $RepoRoot "app_flutter\build\windows\x64\runner\Debug"
$StubDll  = Join-Path $RepoRoot "core_rust\target\x86_64-pc-windows-msvc\debug\voip_core.dll"
$DebugDll = Join-Path $DebugOut "voip_core.dll"

if (Test-Path $StubDll) {
    # Ensure any running instance isn't locking our DLL
    Write-Info "Stopping any running PacketDial instances..."
    Stop-Process -Name "PacketDial" -Force -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Milliseconds 400

    if (-not (Test-Path $DebugOut)) {
        New-Item -ItemType Directory -Path $DebugOut -Force | Out-Null
    }

    Copy-Item -Force $StubDll $DebugOut
    Write-OK "DLL copied to Flutter Debug output"
    Write-OK "    $DebugDll"
} else {
    Write-Warn "voip_core.dll not found at $StubDll"
    Write-Info "App may fail to start. Check the cargo build output above."
}

# ── 3. Flutter pub get + run ─────────────────────────────────────────────────
Write-Step "Launching Flutter app with hot-reload"
Write-Info "Press 'r' to hot-reload Dart code"
Write-Info "Press 'R' to restart (rebuilds Rust + reloads)"
Write-Info "Press 'q' to quit"

Push-Location "$RepoRoot\app_flutter"
try {
    flutter pub get
    flutter run -d windows
} finally {
    Pop-Location
}


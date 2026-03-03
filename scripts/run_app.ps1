#
# Run PacketDial in debug mode with hot-reload support.
# Automatically builds voip_core.dll in debug mode before running.
#
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot

# ── 1. Build Rust core (stub DLL, no PJSIP required) ────────────────────────
Write-Host ">> Building Rust core (debug mode)"
Push-Location "$RepoRoot\core_rust"
cargo build --target x86_64-pc-windows-msvc
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Error "Rust build failed"
    exit 1
}
Pop-Location
Write-Host "    [OK]   Rust core built`n"

# ── 2. Flutter pub get + run ─────────────────────────────────────────────────
Write-Host ">> Running Flutter app"
Push-Location "$RepoRoot\app_flutter"
flutter pub get

# Copy stub DLL into the Flutter debug output directory before launching.
# (The CMake post-build step may not fire correctly when working from a
#  subst'd drive; this explicit copy is always reliable.)
$DebugOut = "build\windows\x64\runner\Debug"
$StubDll  = "..\core_rust\target\x86_64-pc-windows-msvc\debug\voip_core.dll"
if (Test-Path $StubDll) {
    if (-not (Test-Path $DebugOut)) { New-Item -ItemType Directory -Path $DebugOut | Out-Null }
    
    # Ensure any running instance isn't locking our DLL
    Stop-Process -Name "PacketDial" -Force -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Milliseconds 400

    Copy-Item -Force $StubDll $DebugOut
    Write-Host "    [OK]   Copied voip_core.dll -> $DebugOut`n"
} else {
    Write-Warning "voip_core.dll not found at $StubDll - app may fail to start."
}

flutter run -d windows
Pop-Location


#
# Run PacketDial in debug mode with hot-reload support.
# Automatically builds voip_core.dll in debug mode before running.
#
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot

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

Write-Host ">> Running Flutter app"
Push-Location "$RepoRoot\app_flutter"
flutter pub get
flutter run -d windows
Pop-Location

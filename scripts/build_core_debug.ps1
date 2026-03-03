#
# Build voip_core.dll in debug mode (faster compilation for development).
# The DLL will be automatically copied to the Flutter Debug build output
# by CMakeLists.txt when you run `flutter run` or build in Debug mode.
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

$DllPath = "$RepoRoot\core_rust\target\x86_64-pc-windows-msvc\debug\voip_core.dll"
if (Test-Path $DllPath) {
    $size = (Get-Item $DllPath).Length / 1KB
    Write-Host "    [OK]   voip_core.dll built ($([math]::Round($size,1)) KB)"
    Write-Host "           Location: $DllPath"
} else {
    Write-Error "DLL not found at expected location: $DllPath"
    exit 1
}

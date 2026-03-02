$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path "."
$PjsipOut = Join-Path $RepoRoot "engine_pjsip\build\out"
$IncludeDir = Join-Path $PjsipOut "include"
$LibDir = Join-Path $PjsipOut "lib"

if (-not (Test-Path $IncludeDir) -or -not (Test-Path $LibDir)) {
  Write-Host "ERROR: PJSIP build outputs not found."
  Write-Host "Expected:"
  Write-Host " - $IncludeDir"
  Write-Host " - $LibDir"
  Write-Host "Build PJSIP first: ./scripts/build_pjsip.ps1"
  exit 1
}

$env:PJSIP_INCLUDE_DIR = $IncludeDir
$env:PJSIP_LIB_DIR = $LibDir

Push-Location "core_rust"
cargo build --release
Pop-Location

# Copy DLL to Flutter runner for dev convenience
$DllSrc = Join-Path $RepoRoot "core_rust\target\release\voip_core.dll"
$DllDstDir = Join-Path $RepoRoot "app_flutter\windows\runner"
if (-not (Test-Path $DllSrc)) {
  Write-Host "ERROR: Rust DLL not found at $DllSrc"
  exit 1
}
Copy-Item -Force $DllSrc $DllDstDir
Write-Host "Copied DLL to $DllDstDir"

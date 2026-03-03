<#
.SYNOPSIS
    Build Rust core in release mode and copy DLL to Flutter output.

.DESCRIPTION
    Builds the Rust FFI wrapper (voip_core.dll) in release/optimized mode.
    This is slower than debug builds (~1-3 minutes) but produces an optimized
    binary suitable for release artifacts and performance testing.

    This script:
    1. Verifies PJSIP build outputs exist (or uses stub mode)
    2. Builds core_rust/ with cargo (--release mode, full target triple)
    3. Copies voip_core.dll to Flutter's runner folder for platform builds

    Run from the repository root:
        .\scripts\build_core.ps1

.NOTES
    - Uses target x86_64-pc-windows-msvc (MSVC toolchain)
    - Output: core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll
    - If PJSIP build outputs are missing, build will use stub DLL
       (no PJSIP functionality, but app still runs)

.LINK
    See docs/rust-core.md for detailed Rust build documentation
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Color helpers for output
function Write-Step  { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }
function Write-OK    { param($m) Write-Host "    [OK]   $m" -ForegroundColor Green }
function Write-Info  { param($m) Write-Host "    [INFO] $m" -ForegroundColor Yellow }
function Write-Fail  { param($m) Write-Host "    [FAIL] $m" -ForegroundColor Red }

$RepoRoot = Resolve-Path "."

# ---------------------------------------------------------------------------
# Verify PJSIP outputs (if available)
# ---------------------------------------------------------------------------
Write-Step "Verifying PJSIP build outputs"

$PjsipOut = Join-Path $RepoRoot "engine_pjsip\build\out"
$IncludeDir = Join-Path $PjsipOut "include"
$LibDir = Join-Path $PjsipOut "lib"

if ((Test-Path $IncludeDir) -and (Test-Path $LibDir)) {
  Write-OK "PJSIP outputs found - real SIP mode"
  $env:PJSIP_INCLUDE_DIR = $IncludeDir
  $env:PJSIP_LIB_DIR = $LibDir
} else {
  Write-Info "PJSIP outputs not found - stub DLL will be built"
  Write-Info "(To build with real PJSIP, run: .\scripts\build_pjsip.ps1 first)"
}

# ---------------------------------------------------------------------------
# Build Rust core (release mode)
# ---------------------------------------------------------------------------
Write-Step "Building Rust core (release mode)"
Write-Info "This may take 1-3 minutes..."

Push-Location "core_rust"
try {
  cargo build --release --target x86_64-pc-windows-msvc
  if ($LASTEXITCODE -ne 0) {
    Write-Fail "Cargo build failed with exit code $LASTEXITCODE"
    exit 1
  }
} finally {
  Pop-Location
}

Write-OK "Rust core build complete"

# ---------------------------------------------------------------------------
# Verify and copy DLL to Flutter output
# ---------------------------------------------------------------------------
Write-Step "Copying DLL to Flutter runner"

$DllSrc = Join-Path $RepoRoot "core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll"
$DllDstDir = Join-Path $RepoRoot "app_flutter\windows\runner"

if (-not (Test-Path $DllSrc)) {
  Write-Fail "voip_core.dll not found at $DllSrc"
  Write-Info "Check the cargo build output above for errors."
  exit 1
}

if (-not (Test-Path $DllDstDir)) {
  New-Item -ItemType Directory -Path $DllDstDir -Force | Out-Null
}

Copy-Item -Force $DllSrc $DllDstDir
Write-OK "Copied: $DllSrc"
Write-OK "    → $DllDstDir"

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "Rust core (release) built successfully" -ForegroundColor Green
Write-Host "DLL: $DllSrc" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

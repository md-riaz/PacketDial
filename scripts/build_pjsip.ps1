<#
.SYNOPSIS
    Builds pjproject for Windows x64 (Release) and collects headers + libs
    into engine_pjsip/build/out/ for the Rust core to link against.

.DESCRIPTION
    pjproject is part of the repository as a git submodule (engine_pjsip/pjproject/).
    Clone with --recurse-submodules or run:
        git submodule update --init --recursive

    This script:
    1. Verifies the submodule is present.
    2. Locates msbuild from Visual Studio 2022 Build Tools (or any installed VS).
    3. Creates config_site.h if it doesn't exist (required by pjproject).
    4. Builds pjproject-vs14.sln in Release / x64 configuration.
    5. Copies all resulting *.lib files to engine_pjsip/build/out/lib/.
    6. Copies all include directories to engine_pjsip/build/out/include/.

    Run from the repository root:
        .\scripts\build_pjsip.ps1

.PARAMETER Jobs
    Number of parallel MSBuild jobs. Default: number of logical processors.
#>

[CmdletBinding()]
param(
    [int]$Jobs = [Environment]::ProcessorCount
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot     = Split-Path -Parent $PSScriptRoot
$PjProjectDir = Join-Path $RepoRoot 'engine_pjsip\pjproject'
$OutDir       = Join-Path $RepoRoot 'engine_pjsip\build\out'
$OutLib       = Join-Path $OutDir 'lib'
$OutInclude   = Join-Path $OutDir 'include'

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
function Write-Step { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }
function Write-OK   { param($m) Write-Host "    [OK]   $m" -ForegroundColor Green }
function Write-Info { param($m) Write-Host "    [INFO] $m" -ForegroundColor Yellow }
function Write-Fail { param($m) Write-Host "    [FAIL] $m" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# Step 1: Verify submodule is present
# ---------------------------------------------------------------------------
Write-Step "Verifying pjproject submodule"

if (-not (Test-Path (Join-Path $PjProjectDir 'pjlib'))) {
    Write-Fail "pjproject submodule not initialised at $PjProjectDir"
    Write-Info "Run: git submodule update --init --recursive"
    exit 1
}

$PjVersion = '2.14.1'  # pinned in .gitmodules; recorded in stamp for reference
Write-OK "pjproject source present at $PjProjectDir"

# ---------------------------------------------------------------------------
# Step 2: Locate msbuild
# ---------------------------------------------------------------------------
Write-Step "Locating MSBuild"

$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$MsBuild  = $null

if (Test-Path $VsWhere) {
    $vsInstallPath = & $VsWhere -latest -requires 'Microsoft.Component.MSBuild' `
                                -property installationPath 2>$null
    if ($vsInstallPath) {
        $candidate = Join-Path $vsInstallPath 'MSBuild\Current\Bin\MSBuild.exe'
        if (Test-Path $candidate) { $MsBuild = $candidate }
    }
}

# Fallback: search common VS 2022 paths
if (-not $MsBuild) {
    $candidates = @(
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe'
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $MsBuild = $c; break }
    }
}

# Last resort: PATH
if (-not $MsBuild -and (Get-Command 'msbuild' -ErrorAction SilentlyContinue)) {
    $MsBuild = 'msbuild'
}

if (-not $MsBuild) {
    Write-Fail "MSBuild not found. Install Visual Studio 2022 Build Tools with C++ Desktop workload."
    exit 1
}
Write-OK "MSBuild: $MsBuild"

# ---------------------------------------------------------------------------
# Step 3: Create config_site.h if it doesn't exist
# ---------------------------------------------------------------------------
Write-Step "Verifying pjproject configuration"

$ConfigSiteFile = Join-Path $PjProjectDir 'pjlib\include\pj\config_site.h'

if (-not (Test-Path $ConfigSiteFile)) {
    Write-Info "Creating default config_site.h"

    # Create a minimal config_site.h for Windows x64 builds
    $ConfigContent = @"
/* Automatically generated config_site.h for Windows x64 builds */

#pragma once

/* Enable floating point support */
#define PJ_HAS_FLOATING_POINT 1

/* Use Windows WMME audio backend */
#define PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO 0
#define PJMEDIA_AUDIO_DEV_HAS_WMME 1

"@

    Set-Content -Path $ConfigSiteFile -Value $ConfigContent -Encoding UTF8
    Write-OK "Created config_site.h at $ConfigSiteFile"
} else {
    Write-OK "config_site.h already exists"
}

# ---------------------------------------------------------------------------
# Step 4: Locate the pjproject Visual Studio solution
# ---------------------------------------------------------------------------
Write-Step "Locating pjproject Visual Studio solution"

# Use vs14 solution explicitly - it's compatible with VS 2022 and uses .vcxproj format
# vs8 is legacy format using .vcproj which won't work with modern MSBuild
$SlnPath = Join-Path $PjProjectDir 'pjproject-vs14.sln'

if (-not (Test-Path $SlnPath)) {
    Write-Fail "pjproject-vs14.sln not found at $SlnPath"
    Write-Info "The pjproject submodule may be incomplete or corrupted."
    exit 1
}

$SlnFile = Get-Item $SlnPath
Write-OK "Solution: $($SlnFile.FullName)"

# ---------------------------------------------------------------------------
# Step 5: Build pjproject (Release / x64)
# ---------------------------------------------------------------------------
Write-Step "Building pjproject Release x64 with $Jobs parallel job(s)"
Write-Info "This may take 5-20 minutes on first run…"

$MsBuildArgs = @(
    $SlnFile.FullName,
    '/t:pjsua2_lib',
    '/p:Configuration=Release',
    '/p:Platform=x64',
    '/p:PlatformToolset=v143',  # Use VS 2022 toolset instead of v140 (VS 2015)
    "/m:$Jobs",
    '/nologo',
    '/verbosity:minimal',
    '/clp:Summary'
)

Push-Location $PjProjectDir
try {
    & $MsBuild @MsBuildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "MSBuild failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}
Write-OK "pjproject build complete"

# ---------------------------------------------------------------------------
# Step 6: Collect output libs
# ---------------------------------------------------------------------------
Write-Step "Collecting build outputs → $OutDir"

New-Item -ItemType Directory -Force -Path $OutLib    | Out-Null
New-Item -ItemType Directory -Force -Path $OutInclude | Out-Null

# Collect all *.lib files produced by the build (Release x64 only)
# pjproject names them like: pjlib-x86_64-x64-vc14-Release.lib
$LibFiles = @(Get-ChildItem $PjProjectDir -Recurse -Filter '*Release*.lib' |
              Where-Object { $_.FullName -notlike '*Debug*' -and
                             $_.FullName -notlike '*obj*'   -and
                             $_.FullName -notlike '*\CMakeFiles\*' })

if ($LibFiles.Count -eq 0) {
    Write-Fail "No Release *.lib files found under $PjProjectDir"
    Write-Info "Check the MSBuild output above for errors."
    exit 1
}

Write-Info "Found $($LibFiles.Count) lib file(s):"
foreach ($lib in $LibFiles) {
    $destPath = Join-Path $OutLib $lib.Name
    Copy-Item $lib.FullName $destPath -Force
    $sizeKB = [math]::Round($lib.Length / 1KB, 0)
    Write-Host "    $($lib.Name)  ($sizeKB KB)" -ForegroundColor Gray
}
Write-OK "Copied $($LibFiles.Count) lib files → $OutLib"

# ---------------------------------------------------------------------------
# Step 7: Collect include directories
# ---------------------------------------------------------------------------
# Standard pjproject include layout:
#   pjlib/include/         → pj/, pj.h
#   pjlib-util/include/    → pjlib-util/
#   pjnath/include/        → pjnath/
#   pjmedia/include/       → pjmedia/
#   pjsip/include/         → pjsip/, pjsip-ua/, pjsip-simple/, pjsua/, pjsua2/
$IncludeDirs = @(
    'pjlib\include',
    'pjlib-util\include',
    'pjnath\include',
    'pjmedia\include',
    'pjsip\include'
)

foreach ($rel in $IncludeDirs) {
    $src = Join-Path $PjProjectDir $rel
    if (Test-Path $src) {
        # Use "$src\*" to copy the CONTENTS of each include directory directly
        # into $OutInclude, so headers land at out/include/pj/*.h (not
        # out/include/include/pj/*.h which is what Copy-Item without wildcard
        # produces when the destination already exists).
        Copy-Item "$src\*" -Destination $OutInclude -Recurse -Force
        Write-Host "    Copied $rel" -ForegroundColor Gray
    } else {
        Write-Info "Include dir not found (skipping): $src"
    }
}
Write-OK "Include headers → $OutInclude"

# ---------------------------------------------------------------------------
# Write a build-stamp so downstream scripts can detect a fresh build
# ---------------------------------------------------------------------------
$StampFile = Join-Path $OutDir 'pjsip_build_stamp.txt'
Set-Content $StampFile "pjproject=$PjVersion built on $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ') UTC"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " PJSIP BUILD COMPLETE" -ForegroundColor Green
Write-Host " Libs:     $OutLib" -ForegroundColor Green
Write-Host " Headers:  $OutInclude" -ForegroundColor Green
Write-Host " Set PJSIP_LIB_DIR=$OutLib" -ForegroundColor Green
Write-Host " Set PJSIP_INCLUDE_DIR=$OutInclude" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green


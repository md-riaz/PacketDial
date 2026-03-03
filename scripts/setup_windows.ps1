<#
.SYNOPSIS
    One-click environment setup and build script for PacketDial on Windows 10/11.

.DESCRIPTION
    Installs all prerequisites (Git, Visual Studio Build Tools 2022 with C++
    workload, Rust stable, Flutter stable) using winget, then builds
    PacketDial exactly the way the GitHub Actions CI does:

        1. Enable Windows long-path support
        2. Map repository to a short drive letter (X:) to avoid MAX_PATH
        3. Build Rust core  → core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll
        4. flutter pub get
        5. flutter build windows --release
        6. Copy voip_core.dll into the Flutter output folder
        7. .\scripts\package.ps1  → dist\PacketDial-windows-x64.zip

    Run from the repository root in an ELEVATED (Run as Administrator)
    PowerShell window:

        Set-ExecutionPolicy Bypass -Scope Process -Force
        .\scripts\setup_windows.ps1

    Optional flags:
        -SkipInstall   Skip prerequisite installation (tools already present)
        -SkipBuild     Only install prerequisites, do not build
        -FlutterVersion  Flutter SDK version to install (default: 3.41.2)

.PARAMETER SkipInstall
    If set, prerequisite installation steps are skipped.

.PARAMETER SkipBuild
    If set, only prerequisites are installed; no Rust/Flutter build is run.

.PARAMETER FlutterVersion
    Flutter SDK version to install when Flutter is not already present.
    Must match the version used by CI. Default: 3.41.2
#>

[CmdletBinding()]
param(
    [switch]$SkipInstall,
    [switch]$SkipBuild,
    [string]$FlutterVersion = '3.41.2'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step  { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }
function Write-OK    { param($m) Write-Host "    [OK]   $m" -ForegroundColor Green }
function Write-Info  { param($m) Write-Host "    [INFO] $m" -ForegroundColor Yellow }
function Write-Fail  { param($m) Write-Host "    [FAIL] $m" -ForegroundColor Red }

function Test-Cmd($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Invoke-Winget {
    param([string]$Id, [string]$Override = '')
    $wargs = @(
        'install', '--id', $Id,
        '--exact', '--source', 'winget',
        '--silent',
        '--accept-package-agreements',
        '--accept-source-agreements'
    )
    if ($Override) { $wargs += @('--override', $Override) }
    & winget @wargs
    if ($LASTEXITCODE -notin @(0, -1978335189)) {   # 0=ok, -1978335189=already installed
        Write-Fail "winget install $Id exited with code $LASTEXITCODE"
        exit 1
    }
}

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $user    = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    $env:PATH = "$machine;$user"
}

# ---------------------------------------------------------------------------
# 0. Admin check
# ---------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not $isAdmin) {
    Write-Fail "This script must be run as Administrator."
    Write-Host "  Right-click PowerShell -> 'Run as administrator', then re-run:" -ForegroundColor Yellow
    Write-Host "    Set-ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor White
    Write-Host "    .\scripts\setup_windows.ps1" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   PacketDial  -  Windows Setup & Build Script" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Enable long paths (registry + git)
# ---------------------------------------------------------------------------
Write-Step "Enabling Windows long-path support"
try {
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
                     -Name LongPathsEnabled -Value 1
    Write-OK "Registry: LongPathsEnabled = 1"
} catch {
    Write-Info "Could not set registry key (may already be set): $_"
}
if (Test-Cmd 'git') {
    git config --system core.longpaths true 2>$null
    Write-OK "git config --system core.longpaths true"
}

# ---------------------------------------------------------------------------
# 2. Install prerequisites (unless -SkipInstall)
# ---------------------------------------------------------------------------
if (-not $SkipInstall) {

    # 2a. winget availability check
    Write-Step "Checking winget (Windows Package Manager)"
    if (-not (Test-Cmd 'winget')) {
        Write-Fail "winget not found."
        Write-Host "" 
        Write-Host "  Install the 'App Installer' from the Microsoft Store and re-run:" -ForegroundColor Yellow
        Write-Host "    https://aka.ms/getwinget" -ForegroundColor White
        exit 1
    }
    Write-OK "winget found: $(winget --version)"

    # 2b. Git
    Write-Step "Installing Git for Windows"
    if (Test-Cmd 'git') {
        Write-OK "Already installed: $(git --version)"
    } else {
        Write-Info "Not found - installing via winget..."
        Invoke-Winget 'Git.Git'
        Refresh-Path
        Write-OK "Git installed: $(git --version 2>$null)"
    }

    # 2c. Visual Studio Build Tools 2022 with C++ Desktop workload
    Write-Step "Installing Visual Studio Build Tools 2022 (C++ Desktop workload)"
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $hasCpp  = $false
    if (Test-Path $vsWhere) {
        $vsJson = & $vsWhere -products '*' `
                             -requires 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' `
                             -format json 2>$null
        $hasCpp = ($vsJson | ConvertFrom-Json).Count -gt 0
    }
    if ($hasCpp) {
        Write-OK "Visual Studio C++ Build Tools already present"
    } else {
        Write-Info "Not found - installing via winget (this can take 10-20 minutes)..."
        $vsOverride = '--quiet --wait --norestart ' +
                      '--add Microsoft.VisualStudio.Workload.VCTools ' +
                      '--includeRecommended'
        Invoke-Winget 'Microsoft.VisualStudio.2022.BuildTools' $vsOverride
        Write-OK "Visual Studio Build Tools installed"
    }

    # 2d. Rust / rustup
    Write-Step "Installing Rust (rustup)"
    if (Test-Cmd 'cargo') {
        Write-OK "Already installed: $(rustc --version 2>$null)"
    } else {
        Write-Info "Not found - downloading rustup-init.exe..."
        $rustupExe = "$env:TEMP\rustup-init.exe"
        Invoke-WebRequest `
            -Uri 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe' `
            -OutFile $rustupExe -UseBasicParsing
        & $rustupExe -y --default-toolchain stable `
                        --default-host x86_64-pc-windows-msvc `
                        --no-modify-path
        Remove-Item $rustupExe -Force
        $env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
        Write-OK "Rust installed: $(rustc --version 2>$null)"
    }

    # Ensure the MSVC Windows target is present
    Write-Info "Ensuring Rust target x86_64-pc-windows-msvc is registered..."
    rustup target add x86_64-pc-windows-msvc
    Write-OK "Rust target x86_64-pc-windows-msvc ready"

    # 2e. Flutter SDK
    Write-Step "Installing Flutter SDK"
    $flutterInstallDir = "$env:USERPROFILE\flutter"
    if (Test-Cmd 'flutter') {
        Write-OK "Already installed: $(flutter --version --machine 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty frameworkVersion 2>$null)"
    } else {
        # Try winget first (easiest)
        Write-Info "Trying winget install for Flutter..."
        $wingetOk = $false
        try {
            Invoke-Winget 'Google.FlutterSDK'
            Refresh-Path
            if (Test-Cmd 'flutter') { $wingetOk = $true }
        } catch { }

        if (-not $wingetOk) {
            # Fallback: direct download of the exact CI version
            Write-Info "winget Flutter not available - downloading Flutter $FlutterVersion directly..."
            $zipUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/" +
                      "flutter_windows_${FlutterVersion}-stable.zip"
            $zipFile = "$env:TEMP\flutter.zip"
            Write-Info "Downloading: $zipUrl"
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing
            Write-Info "Extracting to $env:USERPROFILE..."
            Expand-Archive -Path $zipFile -DestinationPath $env:USERPROFILE -Force
            Remove-Item $zipFile -Force

            # Persist in user PATH
            $userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
            if ($userPath -notlike "*flutter*") {
                [System.Environment]::SetEnvironmentVariable(
                    'PATH', "$flutterInstallDir\bin;$userPath", 'User')
            }
            $env:PATH = "$flutterInstallDir\bin;$env:PATH"
        }

        Write-OK "Flutter installed"
    }

    Write-Step "Enabling Flutter Windows-desktop support"
    flutter config --enable-windows-desktop
    Write-OK "flutter config --enable-windows-desktop done"

} else {
    Write-Info "-SkipInstall specified - skipping prerequisite installation."
}

# ---------------------------------------------------------------------------
# 3. Verify required tools are on PATH before building
# ---------------------------------------------------------------------------
Write-Step "Verifying required tools"
$missing = @()
foreach ($tool in @('git','cargo','rustup','flutter')) {
    if (Test-Cmd $tool) {
        Write-OK "${tool}: found"
    } else {
        Write-Fail "${tool}: NOT found"
        $missing += $tool
    }
}
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: Missing tools: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Close this window, open a NEW elevated PowerShell, then re-run the script." -ForegroundColor Yellow
    exit 1
}

if ($SkipBuild) {
    Write-Host ""
    Write-OK "Setup complete. -SkipBuild specified - not building."
    exit 0
}

# ---------------------------------------------------------------------------
# 4. Map repository to short drive letter X: (avoids Windows MAX_PATH)
# ---------------------------------------------------------------------------
Write-Step "Mapping repository to X: (avoids MAX_PATH issues)"
$RepoRoot = Split-Path -Parent $PSScriptRoot

# Remove any existing X: mapping first
subst X: /d 2>$null | Out-Null
subst X: $RepoRoot 2>$null
if (Test-Path 'X:\') {
    Set-Location X:\
    Write-OK "Mapped $RepoRoot -> X:"
} else {
    Write-Info "subst failed - continuing from $RepoRoot"
    Set-Location $RepoRoot
}

# ---------------------------------------------------------------------------
# 5. Build PJSIP (source is vendored under engine_pjsip/pjproject/)
# ---------------------------------------------------------------------------
Write-Step "Building pjproject 2.14.1"

$pjOutDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'engine_pjsip\build\out'
$pjStamp  = Join-Path $pjOutDir 'pjsip_build_stamp.txt'

if (Test-Path $pjStamp) {
    Write-OK "PJSIP already built: $(Get-Content $pjStamp -Raw)"
} else {
    & "$PSScriptRoot\build_pjsip.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "PJSIP build failed (exit $LASTEXITCODE)."
        exit 1
    }
    Write-OK "PJSIP build complete"
}

# ---------------------------------------------------------------------------
# 6. Build Rust core  (produces voip_core.dll)
# ---------------------------------------------------------------------------
Write-Step "Building Rust core (voip_core.dll)"

# Pass PJSIP paths to cargo so build.rs picks them up
$env:PJSIP_LIB_DIR     = Join-Path (Resolve-Path .) 'engine_pjsip\build\out\lib'
$env:PJSIP_INCLUDE_DIR = Join-Path (Resolve-Path .) 'engine_pjsip\build\out\include'

Set-Location core_rust
cargo build --release --target x86_64-pc-windows-msvc
Set-Location ..

$dll = "core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll"
if (-not (Test-Path $dll)) {
    Write-Fail "voip_core.dll not found after cargo build."
    exit 1
}
Write-OK "voip_core.dll built -> $dll"

# ---------------------------------------------------------------------------
# 7. Flutter: fetch packages
# ---------------------------------------------------------------------------
Write-Step "Fetching Flutter packages"
Set-Location app_flutter
flutter pub get
Set-Location ..
Write-OK "flutter pub get done"

# ---------------------------------------------------------------------------
# 8. Flutter: build Windows release
# ---------------------------------------------------------------------------
Write-Step "Building Flutter Windows app (release)"
Set-Location app_flutter
flutter clean
flutter build windows --release
Set-Location ..
Write-OK "Flutter build complete"

# ---------------------------------------------------------------------------
# 9. Copy voip_core.dll into Flutter output (mirrors CI step)
# ---------------------------------------------------------------------------
Write-Step "Copying voip_core.dll into Flutter output folder"
$flutterRelease = "app_flutter\build\windows\x64\runner\Release"
if (Test-Path $dll) {
    Copy-Item $dll -Destination $flutterRelease -Force
    Write-OK "Copied voip_core.dll -> $flutterRelease"
} else {
    Write-Info "voip_core.dll not found - PJSIP integration pending, skipping copy."
}

# ---------------------------------------------------------------------------
# 10. Package → dist\PacketDial-windows-x64.zip
# ---------------------------------------------------------------------------
Write-Step "Packaging release artifact"
.\scripts\package.ps1

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " BUILD COMPLETE" -ForegroundColor Green
Write-Host " Artifact: dist\PacketDial-windows-x64.zip" -ForegroundColor Green
Write-Host " Unzip and run PacketDial.exe to launch the app." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

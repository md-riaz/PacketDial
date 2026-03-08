# PacketDial Complete Build Script
# Builds Rust core, Flutter app, and creates installer

param(
    [string]$Version = "1.0.0",
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [switch]$SkipTests,
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "    PacketDial Complete Build Script    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Configuration: $Configuration" -ForegroundColor Yellow
Write-Host ""

# Step 1: Build PJSIP (if needed)
Write-Host "--------------------------------------" -ForegroundColor Gray
Write-Host "[1/5] Checking PJSIP..." -ForegroundColor Cyan
if (!(Test-Path "engine_pjsip\pjproject\libpjproject.lib")) {
    Write-Host "PJSIP not built. Building now..." -ForegroundColor Yellow
    .\scripts\build_pjsip.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: PJSIP build failed!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "PJSIP already built." -ForegroundColor Green
}

# Step 2: Build Rust Core
Write-Host ""
Write-Host "--------------------------------------" -ForegroundColor Gray
Write-Host "[2/5] Building Rust Core..." -ForegroundColor Cyan
.\scripts\build_core.ps1 -Configuration $Configuration
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Rust core build failed!" -ForegroundColor Red
    exit 1
}

# Step 3: Run Tests (optional)
if (!$SkipTests) {
    Write-Host ""
    Write-Host "--------------------------------------" -ForegroundColor Gray
    Write-Host "[3/5] Running Tests..." -ForegroundColor Cyan
    
    Write-Host "  Running Rust tests..." -ForegroundColor Gray
    cd core_rust
    cargo test
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Rust tests failed!" -ForegroundColor Yellow
    }
    cd ..
    
    Write-Host "  Running Flutter tests..." -ForegroundColor Gray
    cd app_flutter
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Flutter tests failed!" -ForegroundColor Yellow
    }
    cd ..
} else {
    Write-Host ""
    Write-Host "--------------------------------------" -ForegroundColor Gray
    Write-Host "[3/5] Skipping tests..." -ForegroundColor Cyan
}

# Step 4: Build Flutter App
Write-Host ""
Write-Host "--------------------------------------" -ForegroundColor Gray
Write-Host "[4/5] Building Flutter App..." -ForegroundColor Cyan
cd app_flutter
$FlutterConfig = $Configuration.ToLower()
flutter build windows --$FlutterConfig
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter build failed!" -ForegroundColor Red
    exit 1
}
cd ..

# Step 5: Create Packages
Write-Host ""
Write-Host "--------------------------------------" -ForegroundColor Gray
Write-Host "[5/5] Creating Packages..." -ForegroundColor Cyan

# Create portable package
Write-Host "  Creating portable package..." -ForegroundColor Gray
.\scripts\build_package.ps1 -Version $Version -NoClean:$NoClean

# Create installer (if Inno Setup available)
Write-Host "  Creating installer..." -ForegroundColor Gray
.\scripts\build_installer.ps1 -Version $Version -NoClean:$NoClean

# Final summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "           BUILD COMPLETE!                " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Output files:" -ForegroundColor Yellow
Write-Host ""

if (Test-Path "dist") {
    Get-ChildItem "dist" -File | ForEach-Object {
        $size = "{0:N2} MB" -f ($_.Length / 1MB)
        Write-Host "  [PKG] $($_.Name) ($size)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  - Portable: Extract ZIP and run PacketDial.exe" -ForegroundColor White
Write-Host "  - Installer: Run PacketDial-Setup-$Version.exe" -ForegroundColor White
Write-Host ""

# Cleanup
if (!$NoClean) {
    Write-Host "Cleaning temporary files..." -ForegroundColor Gray
    if (Test-Path "installer\staging") {
        Remove-Item -Recurse -Force "installer\staging"
    }
}

Write-Host "Done!" -ForegroundColor Green
Write-Host ""

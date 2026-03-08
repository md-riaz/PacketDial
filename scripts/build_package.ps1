# PacketDial Package Builder
# Creates a portable ZIP package with all necessary files

param(
    [string]$Version = "1.0.0",
    [string]$OutputDir = "dist",
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PacketDial Package Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$AppName = "PacketDial"
$BuildDir = "app_flutter\build\windows\x64\runner\Release"
$PackageDir = "$OutputDir\package"

# Create output directory
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host "[1/4] Building Flutter Windows app..." -ForegroundColor Yellow
Set-Location app_flutter
$FlutterConfig = "release"
flutter build windows --$FlutterConfig
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter build failed!" -ForegroundColor Red
    exit 1
}
Set-Location ..

Write-Host "[2/4] Preparing package directory..." -ForegroundColor Yellow
if (Test-Path $PackageDir) {
    Remove-Item -Recurse -Force $PackageDir
}
New-Item -ItemType Directory -Path $PackageDir | Out-Null

# Copy Flutter build output
Write-Host "  Copying build files..." -ForegroundColor Gray
if (!(Test-Path $BuildDir)) {
    Write-Host "ERROR: Build directory not found: $BuildDir" -ForegroundColor Red
    exit 1
}
Copy-Item -Path "$BuildDir\*" -Destination $PackageDir -Recurse -Force

# Copy app.so (AOT compiled Dart code) to data folder
Write-Host "  Copying app.so (AOT compiled code)..." -ForegroundColor Gray
$AppSoSrc = "app_flutter\build\windows\app.so"
$AppSoDest = "$PackageDir\data\app.so"
if (Test-Path $AppSoSrc) {
    if (!(Test-Path "$PackageDir\data")) {
        New-Item -ItemType Directory -Path "$PackageDir\data" | Out-Null
    }
    Copy-Item -Path $AppSoSrc -Destination $AppSoDest -Force
    Write-Host "  ✓ app.so copied successfully" -ForegroundColor Green
}
else {
    Write-Host "  ! WARNING: app.so not found at $AppSoSrc" -ForegroundColor Yellow
}

# Copy Rust core DLL (Explicit check)
Write-Host "  Copying voip_core.dll..." -ForegroundColor Gray
$FoundCore = $false

$P1 = "core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll"
$P2 = "core_rust\target\release\voip_core.dll"
$P3 = "app_flutter\windows\runner\voip_core.dll"

if (Test-Path $P1) {
    Copy-Item -Path $P1 -Destination $PackageDir -Force
    $FoundCore = $true
    Write-Host "  ✓ voip_core.dll found in core_rust output" -ForegroundColor Green
}
elseif (Test-Path $P2) {
    Copy-Item -Path $P2 -Destination $PackageDir -Force
    $FoundCore = $true
    Write-Host "  ✓ voip_core.dll found in core_rust/target/release" -ForegroundColor Green
}
elseif (Test-Path $P3) {
    Copy-Item -Path $P3 -Destination $PackageDir -Force
    $FoundCore = $true
    Write-Host "  ✓ voip_core.dll found in flutter runner directory" -ForegroundColor Green
}
else {
    Write-Host "  ! WARNING: voip_core.dll not found. SIP calls will fail." -ForegroundColor Yellow
}

# Create README
Write-Host "  Creating README..." -ForegroundColor Gray
$ReadmeLines = @(
    "# PacketDial - Windows SIP Softphone",
    "",
    "Version: $Version",
    "",
    "## Installation",
    "",
    "1. Extract ALL files from this ZIP to a folder",
    "2. Run PacketDial.exe from that folder",
    "3. Do NOT move PacketDial.exe out of the folder (it needs the DLLs)",
    "",
    "## Quick Start",
    "",
    "1. Launch PacketDial.exe",
    "2. Go to Accounts tab",
    "3. Click + to add your SIP account",
    "4. Enter your SIP credentials",
    "5. Start making calls!",
    "",
    "## Troubleshooting",
    "",
    "If you see a 'DLL missing' error:",
    "- Make sure you extracted everything (EXE, DLLs, and the 'data' folder).",
    "- Do NOT move the PacketDial.exe file alone.",
    "",
    "---",
    "PacketDial - Modern Windows SIP Client"
)
$ReadmeLines | Out-File -FilePath "$PackageDir\README.txt" -Encoding utf8

# Create uninstaller script
Write-Host "  Creating uninstaller..." -ForegroundColor Gray
$UninstallLines = @(
    "@echo off",
    "echo ========================================",
    "echo PacketDial Uninstaller",
    "echo ========================================",
    "echo.",
    "",
    "set /p confirm=`"Do you want to uninstall PacketDial? (Y/N): `"",
    "if /i not `"%confirm%`"==`"Y`" (",
    "    echo Uninstallation cancelled.",
    "    pause",
    "    exit /b 0",
    ")",
    "",
    "echo.",
    "echo Removing application files...",
    "cd /d `"%~dp0`"",
    "del /q *.exe",
    "del /q *.dll",
    "del /q *.dat",
    "del /q data\*",
    "rmdir /q /s data",
    "del /q README.txt",
    "del /q UNINSTALL.bat",
    "",
    "echo.",
    "set /p removeConfig=`"Remove configuration files? (Y/N): `"",
    "if /i `"%removeConfig%`"==`"Y`" (",
    "    echo Removing configuration...",
    "    if exist `"%APPDATA%\PacketDial`" (",
    "        rmdir /q /s `"%APPDATA%\PacketDial`"",
    "        echo Configuration removed.",
    "    )",
    ")",
    "",
    "echo.",
    "echo ========================================",
    "echo Uninstallation complete!",
    "echo ========================================",
    "pause"
)
$UninstallLines | Out-File -FilePath "$PackageDir\UNINSTALL.bat" -Encoding ascii

# Create start menu shortcut creator
Write-Host "  Creating shortcut creator..." -ForegroundColor Gray
$ShortcutLines = @(
    "@echo off",
    "echo Creating Start Menu shortcut...",
    "",
    "set SCRIPT_DIR=%~dp0",
    "set START_MENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs",
    "",
    "powershell -Command `"`$WshShell = New-Object -ComObject WScript.Shell; `$Shortcut = `$WshShell.CreateShortcut('`$START_MENU\PacketDial.lnk'); `$Shortcut.TargetPath = '`$SCRIPT_DIRPacketDial.exe'; `$Shortcut.WorkingDirectory = '`$SCRIPT_DIR'; `$Shortcut.Save();`"",
    "",
    "echo Shortcut created!",
    "pause"
)
$ShortcutLines | Out-File -FilePath "$PackageDir\CreateShortcut.bat" -Encoding ascii

Write-Host "[3/4] Creating ZIP archive..." -ForegroundColor Yellow
$ZipPath = "$OutputDir\$AppName-$Version-Portable.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path "$PackageDir\*" -DestinationPath $ZipPath -Force

Write-Host "[4/4] Package created!" -ForegroundColor Green

# Cleanup
if (!$NoClean -and (Test-Path $PackageDir)) {
    Write-Host "Cleaning up..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $PackageDir
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Package created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Output: $ZipPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To install:" -ForegroundColor Yellow
Write-Host "1. Extract the ZIP to desired location" -ForegroundColor White
Write-Host "2. Run PacketDial.exe" -ForegroundColor White
Write-Host ""

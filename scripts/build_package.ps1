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
cd app_flutter
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter build failed!" -ForegroundColor Red
    exit 1
}
cd ..

Write-Host "[2/4] Preparing package directory..." -ForegroundColor Yellow
if (Test-Path $PackageDir) {
    Remove-Item -Recurse -Force $PackageDir
}
New-Item -ItemType Directory -Path $PackageDir | Out-Null

# Copy Flutter build output
Write-Host "  Copying build files..." -ForegroundColor Gray
Copy-Item -Path "$BuildDir\*" -Destination $PackageDir -Recurse

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
} else {
    Write-Host "  ✗ ERROR: app.so not found at $AppSoSrc" -ForegroundColor Red
    Write-Host "  Flutter AOT build may have failed. Re-run: flutter build windows --release" -ForegroundColor Red
    exit 1
}

# Create README
Write-Host "  Creating README..." -ForegroundColor Gray
$ReadmeContent = @"
# PacketDial - Windows SIP Softphone

Version: $Version

## Installation

1. Extract this folder to your desired location (e.g., C:\Program Files\PacketDial)
2. Run PacketDial.exe
3. The application will create necessary configuration files on first run

## Quick Start

1. Launch PacketDial.exe
2. Go to Accounts tab
3. Click + to add your SIP account
4. Enter your SIP credentials
5. Start making calls!

## Configuration Files

Configuration files are stored in:
%APPDATA%\PacketDial\

- app_settings.json - App-wide settings
- blf_contacts.json - BLF contact list

## Uninstallation

1. Close PacketDial
2. Delete the installation folder
3. Delete %APPDATA%\PacketDial\ folder (optional, keeps your settings)

## Support

For issues and feature requests, please visit the project repository.

---
PacketDial - Modern Windows SIP Client
"@

Set-Content -Path "$PackageDir\README.txt" -Value $ReadmeContent

# Create uninstaller script
Write-Host "  Creating uninstaller..." -ForegroundColor Gray
$UninstallContent = @"
@echo off
echo ========================================
echo PacketDial Uninstaller
echo ========================================
echo.

set /p confirm="Do you want to uninstall PacketDial? (Y/N): "
if /i not "%confirm%"=="Y" (
    echo Uninstallation cancelled.
    pause
    exit /b 0
)

echo.
echo Removing application files...
cd /d "%~dp0"
del /q *.exe
del /q *.dll
del /q *.dat
del /q data\*
rmdir /q /s data
del /q README.txt
del /q UNINSTALL.bat

echo.
set /p removeConfig="Remove configuration files? (Y/N): "
if /i "%removeConfig%"=="Y" (
    echo Removing configuration...
    if exist "%APPDATA%\PacketDial" (
        rmdir /q /s "%APPDATA%\PacketDial"
        echo Configuration removed.
    )
)

echo.
echo ========================================
echo Uninstallation complete!
echo ========================================
pause
"@

Set-Content -Path "$PackageDir\UNINSTALL.bat" -Value $UninstallContent

# Create start menu shortcut creator
Write-Host "  Creating shortcut creator..." -ForegroundColor Gray
$ShortcutContent = @"
@echo off
echo Creating Start Menu shortcut...

set SCRIPT_DIR=%~dp0
set START_MENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs

powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('$START_MENU\PacketDial.lnk'); $Shortcut.TargetPath = '$SCRIPT_DIRPacketDial.exe'; $Shortcut.WorkingDirectory = '$SCRIPT_DIR'; $Shortcut.Save();"

echo Shortcut created!
pause
"@

Set-Content -Path "$PackageDir\CreateShortcut.bat" -Value $ShortcutContent

Write-Host "[3/4] Creating ZIP archive..." -ForegroundColor Yellow
$ZipPath = "$OutputDir\$AppName-$Version-Portable.zip"
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
Write-Host "3. (Optional) Run CreateShortcut.bat" -ForegroundColor White
Write-Host ""

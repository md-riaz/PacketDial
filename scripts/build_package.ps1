# PacketDial Portable Package Builder
# Flat version to avoid parser bugs in older PowerShell environments

param(
    [string]$Version = "1.0.0",
    [string]$OutputDir = "dist",
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PacketDial Portable Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Setup paths
$AppName = "PacketDial"
$Root = Get-Location
$BuildDir = Join-Path $Root "app_flutter\build\windows\x64\runner\Release"
$PackageDir = Join-Path $Root "$OutputDir\package"
$ZipPath = Join-Path $Root "$OutputDir\$AppName-$Version-Portable.zip"

# Create output directory
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# 2. Build Flutter App
Write-Host "[1/4] Building Flutter Windows app..." -ForegroundColor Yellow
# Ensure stale plugin DLLs from previous dependency sets are not reused.
if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
}
Set-Location app_flutter
& flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter build failed!" -ForegroundColor Red
    Set-Location ..
    exit 1
}
Set-Location ..

# 3. Assemble Package
Write-Host "[2/4] Assembling package directory..." -ForegroundColor Yellow
if (Test-Path $PackageDir) {
    Remove-Item -Recurse -Force $PackageDir
}
New-Item -ItemType Directory -Path $PackageDir | Out-Null

# Copy main build output
Write-Host "  Copying Flutter build files..." -ForegroundColor Gray
if (!(Test-Path $BuildDir)) {
    Write-Host "ERROR: Build directory not found: $BuildDir" -ForegroundColor Red
    exit 1
}
Copy-Item -Path "$BuildDir\*" -Destination $PackageDir -Recurse -Force

# Copy app.so (AOT)
Write-Host "  Ensuring app.so is present..." -ForegroundColor Gray
$AppSoSrc = Join-Path $Root "app_flutter\build\windows\app.so"
$AppSoDest = Join-Path $PackageDir "data\app.so"
if (Test-Path $AppSoSrc) {
    if (!(Test-Path (Join-Path $PackageDir "data"))) {
        New-Item -ItemType Directory -Path (Join-Path $PackageDir "data") | Out-Null
    }
    Copy-Item -Path $AppSoSrc -Destination $AppSoDest -Force
}

# Copy voip_core.dll (MANDATORY - Flat search)
Write-Host "  Copying voip_core.dll..." -ForegroundColor Gray

$P1 = Join-Path $Root "core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll"
$P2 = Join-Path $Root "core_rust\target\release\voip_core.dll"
$P3 = Join-Path $Root "app_flutter\windows\runner\voip_core.dll"

$Copied = $false
if (Test-Path $P1) {
    Copy-Item -Path $P1 -Destination $PackageDir -Force
    $Copied = $true
}
if (!$Copied -and (Test-Path $P2)) {
    Copy-Item -Path $P2 -Destination $PackageDir -Force
    $Copied = $true
}
if (!$Copied -and (Test-Path $P3)) {
    Copy-Item -Path $P3 -Destination $PackageDir -Force
    $Copied = $true
}

if (!$Copied) {
    Write-Host "ERROR: voip_core.dll NOT FOUND!" -ForegroundColor Red
    exit 1
}

# 4. Final Verification
Write-Host "[3/4] Verifying package integrity..." -ForegroundColor Yellow
if (!(Test-Path (Join-Path $PackageDir "PacketDial.exe"))) { Write-Host "Missing PacketDial.exe" -ForegroundColor Red; exit 1 }
if (!(Test-Path (Join-Path $PackageDir "voip_core.dll"))) { Write-Host "Missing voip_core.dll" -ForegroundColor Red; exit 1 }
if (!(Test-Path (Join-Path $PackageDir "flutter_windows.dll"))) { Write-Host "Missing flutter_windows.dll" -ForegroundColor Red; exit 1 }
if (!(Test-Path (Join-Path $PackageDir "data\app.so"))) { Write-Host "Missing data\\app.so" -ForegroundColor Red; exit 1 }

# Create README
$ReadmeText = "PacketDial Portable`r`n`r`n1. Extract ALL files to a folder.`r`n2. Run PacketDial.exe.`r`n`r`nDo NOT move the .exe out of the folder."
$ReadmeText | Out-File -FilePath (Join-Path $PackageDir "README.txt") -Encoding utf8

# 5. Compress
Write-Host "[4/4] Creating ZIP archive..." -ForegroundColor Yellow
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path "$PackageDir\*" -DestinationPath $ZipPath -Force

# Cleanup
if (!$NoClean -and (Test-Path $PackageDir)) {
    Remove-Item -Recurse -Force $PackageDir
}

Write-Host "Package created: $ZipPath" -ForegroundColor Green

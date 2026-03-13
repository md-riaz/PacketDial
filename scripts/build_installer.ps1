# PacketDial Windows Installer Builder
# Creates a Windows installer using Inno Setup, or a ZIP fallback if Inno is unavailable

param(
    [string]$Version = "",
    [string]$OutputDir = "dist",
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"

function Get-PubspecVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PubspecPath
    )

    $match = Select-String -Path $PubspecPath -Pattern '^version:\s*([0-9A-Za-z\.\-\+]+)\s*$' | Select-Object -First 1
    if (-not $match) {
        throw "Could not find version in pubspec.yaml"
    }

    $rawVersion = $match.Matches[0].Groups[1].Value.Trim()
    if ($rawVersion.Contains('+')) {
        return $rawVersion.Split('+')[0]
    }
    return $rawVersion
}

function Update-InnoValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$Pattern,
        [Parameter(Mandatory = $true)]
        [string]$Replacement
    )

    return [regex]::Replace($Content, $Pattern, $Replacement)
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PacketDial Installer Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$AppName = "PacketDial"
$AppPublisher = "PacketDial"
$AppExe = "PacketDial.exe"

# Resolve absolute paths based on script location
$ScriptDir = $PSScriptRoot
$ProjectRoot = (Get-Item (Join-Path $ScriptDir "..")).FullName

$PubspecPath = Join-Path $ProjectRoot "app_flutter\pubspec.yaml"
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-PubspecVersion -PubspecPath $PubspecPath
}

$BuildDir = Join-Path $ProjectRoot "app_flutter\build\windows\x64\runner\Release"
$InstallerDir = Join-Path $ProjectRoot "assets\installer"
$StagingDir = Join-Path $InstallerDir "staging"
$InnoScript = Join-Path $InstallerDir "setup.iss"
$ZipPath = Join-Path $ProjectRoot (Join-Path $OutputDir "PacketDial-$Version.zip")

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

if (!(Test-Path $InstallerDir)) {
    throw "Installer directory not found: $InstallerDir"
}

if (!(Test-Path $InnoScript)) {
    throw "Inno Setup template not found: $InnoScript"
}

Write-Host "[1/5] Building Flutter Windows app..." -ForegroundColor Yellow
Push-Location (Join-Path $ProjectRoot "app_flutter")
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter build failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Write-Host "[2/5] Copying build files..." -ForegroundColor Yellow
if (Test-Path $StagingDir) {
    Remove-Item -Recurse -Force $StagingDir
}
New-Item -ItemType Directory -Path $StagingDir | Out-Null
Copy-Item -Path "$BuildDir\*" -Destination $StagingDir -Recurse -Force

$AppSoSrc = Join-Path $ProjectRoot "app_flutter\build\windows\app.so"
$AppSoDestDir = Join-Path $StagingDir "data"
$AppSoDest = Join-Path $AppSoDestDir "app.so"
if (Test-Path $AppSoSrc) {
    if (!(Test-Path $AppSoDestDir)) {
        New-Item -ItemType Directory -Path $AppSoDestDir | Out-Null
    }
    Copy-Item -Path $AppSoSrc -Destination $AppSoDest -Force
    Write-Host "  app.so copied successfully" -ForegroundColor Green
} else {
    throw "app.so not found at $AppSoSrc"
}

$IconSource = Join-Path $InstallerDir "icon.ico"
if (Test-Path $IconSource) {
    Write-Host "  Icon ready: $IconSource" -ForegroundColor Gray
} else {
    Write-Host "  No custom installer icon found, using default" -ForegroundColor Gray
}

Write-Host "[3/5] Updating Inno Setup script..." -ForegroundColor Yellow
$InnoContent = Get-Content -Path $InnoScript -Raw
$InnoContent = Update-InnoValue -Content $InnoContent -Pattern '(?m)^#define MyAppName ".*"$' -Replacement ('#define MyAppName "{0}"' -f $AppName)
$InnoContent = Update-InnoValue -Content $InnoContent -Pattern '(?m)^#define MyAppVersion ".*"$' -Replacement ('#define MyAppVersion "{0}"' -f $Version)
$InnoContent = Update-InnoValue -Content $InnoContent -Pattern '(?m)^#define MyAppPublisher ".*"$' -Replacement ('#define MyAppPublisher "{0}"' -f $AppPublisher)
$InnoContent = Update-InnoValue -Content $InnoContent -Pattern '(?m)^#define MyAppExeName ".*"$' -Replacement ('#define MyAppExeName "{0}"' -f $AppExe)
$InnoContent = Update-InnoValue -Content $InnoContent -Pattern '(?m)^OutputDir=.*$' -Replacement ('OutputDir=..\{0}' -f $OutputDir)
$InnoContent = Update-InnoValue -Content $InnoContent -Pattern '(?m)^OutputBaseFilename=.*$' -Replacement ('OutputBaseFilename=PacketDial-Setup-{0}' -f $Version)
Set-Content -Path $InnoScript -Value $InnoContent

Write-Host "[4/5] Checking for Inno Setup..." -ForegroundColor Yellow
$InnoPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 5\ISCC.exe"
)

$InnoCompiler = $null
foreach ($path in $InnoPaths) {
    if (Test-Path $path) {
        $InnoCompiler = $path
        break
    }
}

if ($InnoCompiler) {
    Write-Host "[5/5] Building installer with Inno Setup..." -ForegroundColor Yellow
    Write-Host "Using: $InnoCompiler" -ForegroundColor Gray
    & $InnoCompiler $InnoScript
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
    }

    # Inno Setup outputs to assets/dist/, copy to project dist/
    $SourcePath = Join-Path $InstallerDir "dist\PacketDial-Setup-$Version.exe"
    $DestPath = Join-Path $OutputDir "PacketDial-Setup-$Version.exe"
    if (Test-Path $SourcePath) {
        if (!(Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir | Out-Null
        }
        Move-Item -Path $SourcePath -Destination $DestPath -Force
        Remove-Item -Path (Join-Path $InstallerDir "dist") -Recurse -Force
    }

    Write-Host ""
    Write-Host "Installer created successfully" -ForegroundColor Green
    Write-Host "Output: $DestPath" -ForegroundColor Cyan
}

if (!$NoClean -and (Test-Path $StagingDir)) {
    Write-Host ""
    Write-Host "Cleaning up staging directory..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $StagingDir
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green

<#
.SYNOPSIS
    Package the PacketDial Windows release build into a distributable ZIP.

.DESCRIPTION
    Reads the version from version.json, copies the Flutter Windows build
    output and the Rust core DLL into a staging directory, then compresses
    it to dist/PacketDial-windows-x64.zip.

    Run from the repository root:
        .\scripts\package.ps1

    Prerequisites:
        - flutter build windows --release has completed inside app_flutter/
        - cargo build --release has completed inside core_rust/
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
$RepoRoot    = Split-Path -Parent $PSScriptRoot
$VersionFile = Join-Path $RepoRoot 'version.json'
$FlutterBuild = Join-Path $RepoRoot 'app_flutter\build\windows\x64\runner\Release'
$RustRelease  = Join-Path $RepoRoot 'core_rust\target\release'
$DistDir      = Join-Path $RepoRoot 'dist'
$StagingBase  = Join-Path $DistDir  'staging'

# ---------------------------------------------------------------------------
# Read version
# ---------------------------------------------------------------------------
if (-not (Test-Path $VersionFile)) {
    Write-Warning "version.json not found - using 0.0.0-dev"
    $Version = '0.0.0-dev'
} else {
    $vj = Get-Content $VersionFile -Raw | ConvertFrom-Json
    $Version = $vj.version
}

$ArtifactName = "PacketDial-windows-x64"
$StagingDir   = Join-Path $StagingBase $ArtifactName
$ZipPath      = Join-Path $DistDir "${ArtifactName}.zip"

Write-Host "Packaging PacketDial v${Version} → ${ZipPath}"

# ---------------------------------------------------------------------------
# Staging: copy Flutter build output
# ---------------------------------------------------------------------------
if (-not (Test-Path $FlutterBuild)) {
    Write-Error "Flutter Windows release build not found at: $FlutterBuild`nRun: flutter build windows --release"
    exit 1
}

if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
New-Item -ItemType Directory -Path $StagingDir | Out-Null

Write-Host "Copying Flutter build…"
Copy-Item -Path "$FlutterBuild\*" -Destination $StagingDir -Recurse

# ---------------------------------------------------------------------------
# Staging: copy Rust core DLL (if built)
# ---------------------------------------------------------------------------
$CoreDll = Join-Path $RustRelease 'voip_core.dll'
if (Test-Path $CoreDll) {
    Write-Host "Copying voip_core.dll…"
    Copy-Item $CoreDll -Destination $StagingDir
} else {
    Write-Warning "voip_core.dll not found (PJSIP not yet integrated) - skipping"
}

# ---------------------------------------------------------------------------
# Copy version metadata into the bundle
# ---------------------------------------------------------------------------
if (Test-Path $VersionFile) {
    Copy-Item $VersionFile -Destination $StagingDir
}

# ---------------------------------------------------------------------------
# Compress
# ---------------------------------------------------------------------------
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir | Out-Null }
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Write-Host "Compressing to ${ZipPath}…"
Compress-Archive -Path $StagingDir -DestinationPath $ZipPath -CompressionLevel Optimal

# Clean up staging
Remove-Item $StagingBase -Recurse -Force

$size = (Get-Item $ZipPath).Length / 1MB
Write-Host "Done. Artifact: $ZipPath  ($([math]::Round($size,1)) MB)"

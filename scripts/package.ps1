<#
.SYNOPSIS
    Package the PacketDial Windows release build into a distributable ZIP.

.DESCRIPTION
    Prepares the final release artifact by:

    1. Reading version from version.json
    2. Collecting Flutter Windows release build output
    3. Adding the Rust core DLL (voip_core.dll)
    4. Validating required Flutter runtime files (flutter_windows.dll, icudtl.dat, data/)
    5. Compressing everything into dist/PacketDial-windows-x64.zip

    Run from the 

 root:
        .\scripts\package.ps1

    Prerequisites:
        - flutter build windows --release has completed
        - cargo build --release has completed (optional; app works without PJSIP DLL)
        - version.json exists in the repository root

.OUTPUTS
    dist\PacketDial-windows-x64.zip  (distributable package)

.NOTES
    - If voip_core.dll is missing, the package is created without it
      (app runs with stub SIP engine)
    - Flutter build output is validated before packaging
    - Staging directory is cleaned up after compression

.LINK
    See docs/release-process.md for full release workflow
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
$RustReleaseTarget = Join-Path $RepoRoot 'core_rust\target\x86_64-pc-windows-msvc\release'
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
Copy-Item -Path "$FlutterBuild\*" -Destination $StagingDir -Recurse -Force

# ---------------------------------------------------------------------------
# Validate that essential Flutter runtime files were copied
# ---------------------------------------------------------------------------
$RequiredFiles = @(
    (Join-Path $StagingDir 'flutter_windows.dll'),
    (Join-Path $StagingDir 'icudtl.dat')
)

foreach ($f in $RequiredFiles) {
    if (-not (Test-Path $f)) {
        Write-Error "Missing required Flutter file: $f`nThe build output is incomplete. Re-run: flutter build windows --release"
        exit 1
    }
}

# Validate data directory exists
$dataDir = Join-Path $StagingDir 'data'
if (-not (Test-Path $dataDir)) {
    Write-Error "Missing required Flutter directory: $dataDir`nThe build output is incomplete. Re-run: flutter build windows --release"
    exit 1
}

# Check flutter_assets (optional for asset-free builds)
$assetsPath = Join-Path $StagingDir 'data\flutter_assets'
if (Test-Path $assetsPath) {
    Write-Host "flutter_assets found."
} else {
    Write-Host "No flutter_assets folder (valid for asset-free builds)."
}

# Debug: List what was copied to staging
Write-Host "Staging directory contents:"
Get-ChildItem -Path $StagingDir -Recurse | Select-Object -First 20 | ForEach-Object {
    $relativePath = $_.FullName.Substring($StagingDir.Length + 1)
    if ($_.PSIsContainer) {
        Write-Host "  [DIR]  $relativePath"
    } else {
        $size = [math]::Round($_.Length / 1KB, 1)
        Write-Host "  [FILE] $relativePath ($size KB)"
    }
}

# ---------------------------------------------------------------------------
# Staging: copy Rust core DLL (if built)
# ---------------------------------------------------------------------------
# Prefer the target-triple path (used when building with --target x86_64-pc-windows-msvc),
# fall back to the plain release path.
$CoreDllTarget = Join-Path $RustReleaseTarget 'voip_core.dll'
$CoreDllPlain  = Join-Path $RustRelease 'voip_core.dll'
if (Test-Path $CoreDllTarget) {
    $CoreDll = $CoreDllTarget
} elseif (Test-Path $CoreDllPlain) {
    $CoreDll = $CoreDllPlain
} else {
    $CoreDll = $null
}

if ($CoreDll) {
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
# Compress the contents of the staging directory, not the directory itself
# This ensures the ZIP contains PacketDial.exe, data/, etc. at the root level
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

# Clean up staging
Remove-Item $StagingBase -Recurse -Force

$size = (Get-Item $ZipPath).Length / 1MB
Write-Host "Done. Artifact: $ZipPath  ($([math]::Round($size,1)) MB)"

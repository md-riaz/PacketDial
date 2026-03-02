<#
.SYNOPSIS
    Copy Flutter Windows runtime files into the build output directory.

.DESCRIPTION
    After 'flutter build windows --release', this script ensures that
    flutter_windows.dll, icudtl.dat, flutter_assets/, and app.so are all
    present in the runner Release directory.

    CMake's install(FILES ...) rules carry OPTIONAL so they do not fail when
    ephemeral files are absent at install-time on CI.  This script is the
    belt-and-suspenders fallback: it copies any missing files from the
    ephemeral source-tree directory (written by flutter_assemble) or, as a
    last resort, from the Flutter SDK artifact cache.

    Run from the repository root:
        .\scripts\copy-flutter-runtime.ps1
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$dest      = "app_flutter\build\windows\x64\runner\Release"
$ephemeral = "app_flutter\windows\flutter\ephemeral"
$buildDir  = "app_flutter\build\windows\x64"
$flutterRoot = $env:FLUTTER_ROOT

if (-not (Test-Path $dest)) {
    Write-Error "Runner Release directory not found: $dest`nRun: flutter build windows --release first."
    exit 1
}

# ---------------------------------------------------------------------------
# Helper: copy a single file if the destination does not already have it.
# ---------------------------------------------------------------------------
function Copy-IfMissing {
    param(
        [string]$FileName,
        [string]$DestDir,
        [string[]]$SourceCandidates
    )
    $dst = Join-Path $DestDir $FileName
    if (Test-Path $dst) {
        Write-Host "$FileName already present in output"
        return
    }
    foreach ($src in $SourceCandidates) {
        if (Test-Path $src) {
            Copy-Item $src -Destination $DestDir -Force
            Write-Host "Copied $FileName  ← $src"
            return
        }
    }
    Write-Warning "$FileName not found in any candidate location:`n  $($SourceCandidates -join "`n  ")"
}

# ---------------------------------------------------------------------------
# flutter_windows.dll
# ---------------------------------------------------------------------------
Copy-IfMissing 'flutter_windows.dll' $dest @(
    "$ephemeral\flutter_windows.dll",
    "$flutterRoot\bin\cache\artifacts\engine\windows-x64-release\flutter_windows.dll",
    "$flutterRoot\bin\cache\artifacts\engine\windows-x64\flutter_windows.dll"
)

# ---------------------------------------------------------------------------
# icudtl.dat
# ---------------------------------------------------------------------------
Copy-IfMissing 'icudtl.dat' $dest @(
    "$ephemeral\icudtl.dat",
    "$flutterRoot\bin\cache\artifacts\engine\windows-x64-release\icudtl.dat",
    "$flutterRoot\bin\cache\artifacts\engine\windows-x64\icudtl.dat"
)

# ---------------------------------------------------------------------------
# flutter_assets  →  data\flutter_assets\
# ---------------------------------------------------------------------------
$dstAssets = Join-Path $dest "data\flutter_assets"
if (Test-Path $dstAssets) {
    Write-Host "flutter_assets already present in output"
} else {
    $srcAssets = "$buildDir\flutter_assets"
    if (Test-Path $srcAssets) {
        $dataDir = Join-Path $dest "data"
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        Copy-Item -Path $srcAssets -Destination $dataDir -Recurse -Force
        Write-Host "Copied flutter_assets  ← $srcAssets"
    } else {
        Write-Warning "flutter_assets source not found at $srcAssets"
    }
}

# ---------------------------------------------------------------------------
# app.so  →  data\app.so  (AOT Dart snapshot; Release builds only)
# The cmake AOT_LIBRARY variable resolves to PROJECT_BINARY_DIR/windows/app.so
# which is buildDir\windows\app.so; some Flutter versions write it directly
# under buildDir, so we try both locations.
# ---------------------------------------------------------------------------
$dstAppSo = Join-Path $dest "data\app.so"
if (Test-Path $dstAppSo) {
    Write-Host "app.so already present in output"
} else {
    $srcAppSo = $null
    foreach ($candidate in @("$buildDir\windows\app.so", "$buildDir\app.so")) {
        if (Test-Path $candidate) { $srcAppSo = $candidate; break }
    }
    if ($srcAppSo) {
        $dataDir = Join-Path $dest "data"
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        Copy-Item -Path $srcAppSo -Destination $dataDir -Force
        Write-Host "Copied app.so  ← $srcAppSo"
    } else {
        Write-Warning "app.so not found under $buildDir (AOT snapshot may be embedded in the exe)"
    }
}

Write-Host "Flutter runtime copy step complete."

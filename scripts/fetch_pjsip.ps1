<#
.SYNOPSIS
    Downloads pjproject source code from GitHub and extracts it to engine_pjsip/pjproject/.

.DESCRIPTION
    Fetches the pinned pjproject release (v2.14.1) from the official GitHub repository
    and extracts it to engine_pjsip/pjproject/.  Does nothing if the directory already
    exists with the correct version, making it safe to call repeatedly.

    Run from the repository root:
        .\scripts\fetch_pjsip.ps1

.PARAMETER PjVersion
    pjproject release tag to download. Default: 2.14.1

.PARAMETER Force
    Re-download even if engine_pjsip/pjproject/ already exists.
#>

[CmdletBinding()]
param(
    [string]$PjVersion = '2.14.1',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$TargetDir  = Join-Path $RepoRoot 'engine_pjsip\pjproject'
$VersionFile = Join-Path $TargetDir '.pjproject_version'

# ---------------------------------------------------------------------------
# Check if already fetched at the right version
# ---------------------------------------------------------------------------
if ((Test-Path $VersionFile) -and -not $Force) {
    $existing = (Get-Content $VersionFile -Raw).Trim()
    if ($existing -eq $PjVersion) {
        Write-Host "[fetch_pjsip] pjproject $PjVersion already present at engine_pjsip/pjproject/ — skipping download."
        exit 0
    }
    Write-Host "[fetch_pjsip] Version mismatch (have $existing, need $PjVersion) — re-downloading."
}

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
$ZipUrl  = "https://github.com/pjsip/pjproject/archive/refs/tags/$PjVersion.zip"
$TmpZip  = Join-Path $env:TEMP "pjproject-$PjVersion.zip"
$TmpDir  = Join-Path $env:TEMP "pjproject-extract-$$"

Write-Host "[fetch_pjsip] Downloading pjproject $PjVersion from GitHub…"
Write-Host "  URL: $ZipUrl"

# Use TLS 1.2 for older .NET on Windows Server images
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $TmpZip -UseBasicParsing
} catch {
    Write-Error "Download failed: $_`nURL: $ZipUrl"
    exit 1
}

Write-Host "[fetch_pjsip] Download complete ($([math]::Round((Get-Item $TmpZip).Length / 1MB, 1)) MB)"

# ---------------------------------------------------------------------------
# Extract
# ---------------------------------------------------------------------------
Write-Host "[fetch_pjsip] Extracting…"
if (Test-Path $TmpDir) { Remove-Item $TmpDir -Recurse -Force }
New-Item -ItemType Directory -Path $TmpDir | Out-Null

Expand-Archive -Path $TmpZip -DestinationPath $TmpDir -Force

# The zip contains a single directory named pjproject-<version>/
$Extracted = Get-ChildItem $TmpDir -Directory | Select-Object -First 1
if (-not $Extracted) {
    Write-Error "Unexpected archive structure — no subdirectory found in $TmpDir"
    exit 1
}

# ---------------------------------------------------------------------------
# Move into place
# ---------------------------------------------------------------------------
if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force }
Move-Item $Extracted.FullName $TargetDir
Write-Host "[fetch_pjsip] Extracted to: $TargetDir"

# ---------------------------------------------------------------------------
# Copy committed config_site.h into position (overwrites pjproject default)
# ---------------------------------------------------------------------------
$ConfigSrc  = Join-Path $RepoRoot 'engine_pjsip\pjproject_config_site.h'
$ConfigDest = Join-Path $TargetDir 'pjlib\include\pj\config_site.h'
if (Test-Path $ConfigSrc) {
    $ConfigDestDir = Split-Path $ConfigDest
    if (-not (Test-Path $ConfigDestDir)) {
        New-Item -ItemType Directory -Path $ConfigDestDir | Out-Null
    }
    Copy-Item $ConfigSrc $ConfigDest -Force
    Write-Host "[fetch_pjsip] Copied pjproject_config_site.h → pjlib/include/pj/config_site.h"
}

# ---------------------------------------------------------------------------
# Write version stamp
# ---------------------------------------------------------------------------
Set-Content $VersionFile $PjVersion -NoNewline
Write-Host "[fetch_pjsip] Done. pjproject $PjVersion ready at engine_pjsip/pjproject/"

# Cleanup
Remove-Item $TmpZip -Force -ErrorAction SilentlyContinue
Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue

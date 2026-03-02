Param(
  [string]$PjProjectDir = "$(Resolve-Path ./engine_pjsip/pjproject)",
  [string]$OutDir = "$(Resolve-Path ./engine_pjsip/build/out)"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $PjProjectDir)) {
  Write-Host "ERROR: pjproject not found at $PjProjectDir"
  Write-Host "Place pjproject source at engine_pjsip/pjproject/"
  exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "NOTE: This script is a practical scaffold."
Write-Host "PJSIP can be built on Windows via Visual Studio projects or via its build scripts."
Write-Host "You may need to adjust these commands depending on your pjproject version."

# Typical approach:
# 1) Generate/prepare config_site.h (optional)
# 2) Build pjproject using Visual Studio solution
#
# For maximum compatibility, we provide guidance rather than assuming exact paths.

Write-Host ""
Write-Host "Next steps (manual, recommended):"
Write-Host "1) Open $PjProjectDir/pjproject-vs14.sln (or similar) in Visual Studio."
Write-Host "2) Build 'pjlib', 'pjlib-util', 'pjnath', 'pjmedia', 'pjsip' in Release x64."
Write-Host "3) Copy resulting .lib files and includes into:"
Write-Host "   $OutDir/lib and $OutDir/include"
Write-Host ""

New-Item -ItemType Directory -Force -Path (Join-Path $OutDir "lib") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir "include") | Out-Null

Write-Host "Created output folders:"
Write-Host " - $OutDir/lib"
Write-Host " - $OutDir/include"
Write-Host ""
Write-Host "When done, run: ./scripts/build_core.ps1"

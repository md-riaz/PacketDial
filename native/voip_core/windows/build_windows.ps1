param(
  [string]$Configuration = "Release",
  [string]$PjsipRoot = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$moduleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$defaultPjsipRoot = Join-Path $repoRoot "reference\engine_pjsip\build\out"
$defaultOpenSslRoot = Join-Path $repoRoot "reference\vcpkg\installed\x64-windows-static-md"
$resolvedPjsipRoot = if ($PjsipRoot) { (Resolve-Path $PjsipRoot).Path } else { $defaultPjsipRoot }
$resolvedOpenSslRoot = $defaultOpenSslRoot
$buildDir = Join-Path $moduleRoot "build\windows"

$cmakeCommand = Get-Command cmake -ErrorAction SilentlyContinue
$cmake = if ($cmakeCommand) { $cmakeCommand.Source } else { $null }
if (-not $cmake) {
  $cmakeCandidates = @(
    'C:\Program Files\CMake\bin\cmake.exe',
    'C:\Program Files (x86)\CMake\bin\cmake.exe',
    'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
    'C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
    'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
  )
  foreach ($candidate in $cmakeCandidates) {
    if (Test-Path $candidate) {
      $cmake = $candidate
      break
    }
  }
}

if (-not $cmake) {
  throw "CMake not found. Install CMake or Visual Studio CMake tools."
}

Write-Host "PacketDial shared native module: Windows build entrypoint"
Write-Host "Module root: $moduleRoot"
Write-Host "PJSIP root:  $resolvedPjsipRoot"
Write-Host "OpenSSL:     $resolvedOpenSslRoot"
Write-Host "Config:      $Configuration"
Write-Host "CMake:       $cmake"

if (-not (Test-Path (Join-Path $resolvedPjsipRoot "include")) -or
    -not (Test-Path (Join-Path $resolvedPjsipRoot "lib"))) {
  throw "Expected staged PJSIP include/lib folders under $resolvedPjsipRoot"
}
if (-not (Test-Path (Join-Path $resolvedOpenSslRoot "include")) -or
    -not (Test-Path (Join-Path $resolvedOpenSslRoot "lib"))) {
  throw "Expected staged OpenSSL include/lib folders under $resolvedOpenSslRoot"
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
if (Test-Path (Join-Path $buildDir "CMakeCache.txt")) {
  Remove-Item (Join-Path $buildDir "CMakeCache.txt") -Force
}
if (Test-Path (Join-Path $buildDir "CMakeFiles")) {
  Remove-Item (Join-Path $buildDir "CMakeFiles") -Recurse -Force
}

Write-Host ""
Write-Host "Configuring native/voip_core against staged Windows PJSIP output"
& $cmake -S $moduleRoot -B $buildDir "-DVOIP_CORE_PJSIP_ROOT=$resolvedPjsipRoot" "-DVOIP_CORE_OPENSSL_ROOT=$resolvedOpenSslRoot"
if ($LASTEXITCODE -ne 0) {
  throw "CMake configure failed."
}

Write-Host "Building voip_core.dll"
& $cmake --build $buildDir --config $Configuration
if ($LASTEXITCODE -ne 0) {
  throw "CMake build failed."
}

Write-Host ""
Write-Host "Windows shared-base build complete."
Write-Host "Expected artifact under: $buildDir"

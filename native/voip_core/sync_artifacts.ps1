param(
  [ValidateSet("arm64-v8a")]
  [string[]]$AndroidAbis = @("arm64-v8a"),
  [string]$WindowsConfiguration = "Release",
  [switch]$SkipWindowsBuild,
  [switch]$SkipAndroidBuild
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$androidBuildScript = Join-Path $PSScriptRoot "android\build_android.ps1"
$windowsBuildScript = Join-Path $PSScriptRoot "windows\build_windows.ps1"
$moduleRoot = Resolve-Path $PSScriptRoot
$appAndroidLibRoot = Join-Path $repoRoot "apps\softphone_app\android\app\src\main\jniLibs"
$vendorWindowsDll = Join-Path $repoRoot "native\vendor\windows\x64\voip_core.dll"
$ndkRoot = $env:ANDROID_NDK_ROOT
if (-not $ndkRoot) { $ndkRoot = $env:ANDROID_NDK_HOME }
if (-not $ndkRoot) { $ndkRoot = $env:ANDROID_NDK }
if (-not $ndkRoot) { $ndkRoot = "C:\Android\Sdk\ndk\28.2.13676358" }

function Resolve-CMake {
  $cmakeCommand = Get-Command cmake -ErrorAction SilentlyContinue
  if ($cmakeCommand) {
    return $cmakeCommand.Source
  }
  foreach ($candidate in @(
    "C:\Program Files\CMake\bin\cmake.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
  )) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }
  throw "CMake not found."
}

function Resolve-Ninja {
  foreach ($candidate in @(
    "C:\Android\Sdk\cmake\3.22.1\bin\ninja.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe"
  )) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }
  throw "Ninja not found."
}

if (-not $SkipWindowsBuild) {
  & powershell -ExecutionPolicy Bypass -File $windowsBuildScript -Configuration $WindowsConfiguration
  if ($LASTEXITCODE -ne 0) {
    throw "Windows shared-core build failed."
  }
}

$builtWindowsDll = Join-Path $moduleRoot "build\windows\$WindowsConfiguration\voip_core.dll"
if (Test-Path $builtWindowsDll) {
  Copy-Item $builtWindowsDll $vendorWindowsDll -Force
}

if (-not $SkipAndroidBuild) {
  $cmake = Resolve-CMake
  $ninja = Resolve-Ninja
  foreach ($abi in $AndroidAbis) {
    & powershell -ExecutionPolicy Bypass -File $androidBuildScript -Abi $abi -ApiLevel "24" -NdkRoot $ndkRoot
    if ($LASTEXITCODE -ne 0) {
      throw "Android PJSIP stage failed for $abi."
    }

    $stageRoot = Join-Path $moduleRoot "android\out\$abi"
    $buildDir = Join-Path $moduleRoot "build\android-$abi"

    & $cmake -S $moduleRoot -B $buildDir -G Ninja `
      "-DCMAKE_MAKE_PROGRAM=$ninja" `
      "-DCMAKE_BUILD_TYPE=Release" `
      "-DCMAKE_TOOLCHAIN_FILE=$ndkRoot\build\cmake\android.toolchain.cmake" `
      "-DANDROID_ABI=$abi" `
      "-DANDROID_PLATFORM=24" `
      "-DVOIP_CORE_PJSIP_ROOT=$stageRoot"
    if ($LASTEXITCODE -ne 0) {
      throw "Android shared-core configure failed for $abi."
    }

    & $cmake --build $buildDir --config Release
    if ($LASTEXITCODE -ne 0) {
      throw "Android shared-core build failed for $abi."
    }

    $builtSo = Join-Path $buildDir "libvoip_core.so"
    $appAbiDir = Join-Path $appAndroidLibRoot $abi
    New-Item -ItemType Directory -Force -Path $appAbiDir | Out-Null
    Copy-Item $builtSo (Join-Path $appAbiDir "libvoip_core.so") -Force
  }
}

Write-Host "Synced native artifacts:"
Write-Host "  Windows DLL: $vendorWindowsDll"
foreach ($abi in $AndroidAbis) {
  $androidLibPath = Join-Path $appAndroidLibRoot "$abi\libvoip_core.so"
  Write-Host "  Android ${abi}: $androidLibPath"
}

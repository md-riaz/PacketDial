param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("arm64-v8a", "armeabi-v7a", "x86_64")]
  [string]$Abi,

  [string]$NdkRoot = $env:ANDROID_NDK_ROOT,
  [string]$ApiLevel = "24",
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$moduleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$pjProjectRoot = Resolve-Path (Join-Path $repoRoot "reference\engine_pjsip\pjproject")
$configHeader = Resolve-Path (Join-Path $PSScriptRoot "pjproject_config_site.h")
$stageRoot = Join-Path $PSScriptRoot "out\$Abi"
$stageInclude = Join-Path $stageRoot "include"
$stageLib = Join-Path $stageRoot "lib"

if (-not $NdkRoot) {
  throw "ANDROID_NDK_ROOT is not set."
}

$hostTag = "windows-x86_64"
$toolchain = Join-Path $NdkRoot "toolchains\llvm\prebuilt\$hostTag"
$clang = Join-Path $toolchain "bin\clang.exe"
$abiTriple = switch ($Abi) {
  "arm64-v8a" { "aarch64-linux-android" }
  "armeabi-v7a" { "armv7a-linux-androideabi" }
  "x86_64" { "x86_64-linux-android" }
}
$archiveSuffix = switch ($Abi) {
  "arm64-v8a" { "aarch64-unknown-linux-android" }
  "armeabi-v7a" { "armv7-unknown-linux-android" }
  "x86_64" { "x86_64-unknown-linux-android" }
}
$hostTag = "windows-x86_64"
$toolchainBin = Join-Path $NdkRoot "toolchains\llvm\prebuilt\$hostTag\bin"
$targetCc = Join-Path $toolchainBin "$abiTriple$ApiLevel-clang.cmd"
$targetCxx = Join-Path $toolchainBin "$abiTriple$ApiLevel-clang++.cmd"
$ar = Join-Path $toolchainBin "llvm-ar.exe"
$ranlib = Join-Path $toolchainBin "llvm-ranlib.exe"
$strip = Join-Path $toolchainBin "llvm-strip.exe"
$gitBash = @(
  "C:\Program Files\Git\bin\bash.exe",
  "C:\Program Files\Git\usr\bin\bash.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
$makeExe = @(
  (Get-Command mingw32-make.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
  (Join-Path $repoRoot "reference\vcpkg\downloads\tools\perl\5.42.0.1\c\bin\mingw32-make.exe")
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $gitBash) {
  throw "Git Bash was not found. Install Git for Windows or update the build script path."
}

if (-not $makeExe) {
  throw "mingw32-make.exe was not found. Install MinGW make or stage the vendored make binary."
}

Write-Host "Preparing Android PJSIP build for $Abi"

$pjConfigDst = Join-Path $pjProjectRoot "pjlib\include\pj\config_site.h"
Copy-Item $configHeader $pjConfigDst -Force
if (Test-Path $stageRoot) {
  Remove-Item $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stageInclude,$stageLib | Out-Null

Push-Location $pjProjectRoot
try {
  $env:ANDROID_NDK_ROOT = $NdkRoot
  $env:TARGET_ABI = $Abi
  $env:APP_PLATFORM = "android-$ApiLevel"
  $env:CC = $targetCc
  $env:CXX = $targetCxx
  $env:AR = $ar
  $env:RANLIB = $ranlib
  $env:STRIP = $strip

  $configureArgs = @("--use-ndk-cflags")
  $configureArgs += @(
    "--disable-libwebrtc",
    "--disable-libyuv"
  )

  Write-Host "Running configure-android for $Abi"
  $tempScript = Join-Path $env:TEMP "packetdial-android-build-$Abi.sh"
  $buildSteps = if ($SkipBuild) {
    @()
  } else {
    @(
      "make clean",
      "make -j$([Environment]::ProcessorCount)"
    )
  }
  $bashScript = @(
    "#!/usr/bin/env bash",
    "set -e",
    "mkdir -p /tmp/pd-bin",
    "cat >/tmp/pd-bin/make <<'EOF'",
    "#!/usr/bin/env bash",
    "exec '$($makeExe -replace '\\','/')' ""`$@""",
    "EOF",
    "chmod +x /tmp/pd-bin/make",
    "export PATH=""/tmp/pd-bin:`$PATH""",
    "cd '$($pjProjectRoot.Path -replace '\\','/' -replace '^([A-Za-z]):','/$1')'",
    "tr -d '\r' < ./configure-android >/tmp/packetdial-configure-android",
    "chmod +x /tmp/packetdial-configure-android",
    "/tmp/packetdial-configure-android $($configureArgs -join ' ')",
    "perl -pi -e 's!$($repoRoot.Path -replace '\\','/' -replace '^([A-Za-z]):','/$1')!$($repoRoot.Path -replace '\\','/')!g' build.mak build/os-auto.mak */build/os-auto.mak third_party/build/os-auto.mak third_party/build/*/Makefile 2>/dev/null || true"
  ) + $buildSteps -join "`n"
  [System.IO.File]::WriteAllText($tempScript, $bashScript)

  & $gitBash $tempScript
  if ($LASTEXITCODE -ne 0) {
    throw "Android pjproject build failed for $Abi"
  }
}
finally {
  Pop-Location
}

Write-Host "Staging headers and libs to $stageRoot"

$includeDirs = @(
  "pjlib\include",
  "pjlib-util\include",
  "pjnath\include",
  "pjmedia\include",
  "pjsip\include"
)
foreach ($dir in $includeDirs) {
  $src = Join-Path $pjProjectRoot $dir
  if (Test-Path $src) {
    Copy-Item "$src\*" -Destination $stageInclude -Recurse -Force
  }
}

Get-ChildItem $pjProjectRoot -Recurse -File |
  Where-Object {
    $_.Extension -eq ".a" -and
    $_.BaseName -like "*-$archiveSuffix" -and
    $_.DirectoryName -notmatch "\\tests\\"
  } |
  ForEach-Object {
    Copy-Item $_.FullName (Join-Path $stageLib $_.Name) -Force
  }

Write-Host ""
Write-Host "Android staged output ready:"
Write-Host "  include: $stageInclude"
Write-Host "  lib:     $stageLib"
Write-Host ""
Write-Host "Next:"
Write-Host "  cmake -S native/voip_core -B build/android-$Abi -DVOIP_CORE_PJSIP_ROOT=$stageRoot"
Write-Host "  cmake --build build/android-$Abi --config Release"

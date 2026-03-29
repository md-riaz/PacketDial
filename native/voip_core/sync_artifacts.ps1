param(
  [ValidateSet("arm64-v8a")]
  [string[]]$AndroidAbis = @("arm64-v8a")
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$appAndroidLibRoot = Join-Path $repoRoot "apps\softphone_app\android\app\src\main\jniLibs"
$vendorWindowsDll = Join-Path $repoRoot "native\vendor\windows\x64\voip_core.dll"

if (-not (Test-Path $vendorWindowsDll)) {
  throw "Missing vendored Windows telephony binary at $vendorWindowsDll"
}

if (-not (Test-Path $appAndroidLibRoot)) {
  New-Item -ItemType Directory -Force -Path $appAndroidLibRoot | Out-Null
}

Get-ChildItem -Path $appAndroidLibRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
  if ($AndroidAbis -notcontains $_.Name) {
    Remove-Item $_.FullName -Recurse -Force
  }
}

foreach ($abi in $AndroidAbis) {
  $appAbiDir = Join-Path $appAndroidLibRoot $abi
  $appSo = Join-Path $appAbiDir "libvoip_core.so"
  if (-not (Test-Path $appSo)) {
    throw "Missing vendored Android telephony binary for $abi at $appSo"
  }
}

$windowsDll = Get-Item $vendorWindowsDll
Write-Host "Validated native artifacts:"
Write-Host "  Windows DLL: $($windowsDll.FullName) ($($windowsDll.Length) bytes)"
foreach ($abi in $AndroidAbis) {
  $androidLibPath = Join-Path $appAndroidLibRoot "$abi\libvoip_core.so"
  $androidLib = Get-Item $androidLibPath
  Write-Host "  Android ${abi}: $($androidLib.FullName) ($($androidLib.Length) bytes)"
}
Write-Host ""
Write-Host "Current policy: this repository consumes prebuilt native telephony binaries only."

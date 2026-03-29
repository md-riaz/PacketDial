param(
  [ValidateSet("arm64-v8a")]
  [string]$Abi = "arm64-v8a"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$vendoredSo = Join-Path $repoRoot "apps\softphone_app\android\app\src\main\jniLibs\$Abi\libvoip_core.so"

Write-Host "PacketDial shared native module: Android binary-only workflow"
Write-Host "This repository does not rebuild the Android telephony core from source."
Write-Host "Expected prebuilt runtime library: $vendoredSo"

if (-not (Test-Path $vendoredSo)) {
  throw "Missing vendored Android telephony binary for $Abi at $vendoredSo"
}

$lib = Get-Item $vendoredSo
Write-Host ""
Write-Host "Android native runtime is present:"
Write-Host "  ABI:    $Abi"
Write-Host "  Path:   $($lib.FullName)"
Write-Host "  Length: $($lib.Length)"
Write-Host ""
Write-Host "To update it, replace the checked-in jniLibs binary with a new ABI-compatible binary drop."

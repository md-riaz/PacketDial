param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$vendoredDll = Join-Path $repoRoot "native\vendor\windows\x64\voip_core.dll"

Write-Host "PacketDial shared native module: Windows binary-only workflow"
Write-Host "This repository does not rebuild the Windows telephony core from source."
Write-Host "Expected prebuilt runtime DLL: $vendoredDll"

if (-not (Test-Path $vendoredDll)) {
  throw "Missing vendored Windows telephony binary at $vendoredDll"
}

$dll = Get-Item $vendoredDll
Write-Host ""
Write-Host "Windows native runtime is present:"
Write-Host "  Path:   $($dll.FullName)"
Write-Host "  Length: $($dll.Length)"
Write-Host ""
Write-Host "To update it, replace the vendored DLL with a new ABI-compatible binary drop."

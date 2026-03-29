# Register PacketDial Protocol Handlers (tel: and sip:)
# Requires pd.exe to be built and located in the bin/ directory or tools/pd/target/debug/

$ErrorActionPreference = "Stop"

# Path to the pd.exe utility
$PdExe = Join-Path $PSScriptRoot "..\tools\pd\target\debug\pd.exe"
if (-not (Test-Path $PdExe)) {
    $PdExe = Join-Path $PSScriptRoot "..\bin\pd.exe"
}

if (-not (Test-Path $PdExe)) {
    Write-Error "pd.exe not found. Please build it first: cd tools/pd; cargo build"
}

$PdExe = [System.IO.Path]::GetFullPath($PdExe)
Write-Host "Registering protocol handler: $PdExe"

function Register-Protocol($Protocol) {
    $Root = "HKCU:\Software\Classes\$Protocol"
    if (-not (Test-Path $Root)) { New-Item -Path $Root -Force }
    Set-ItemProperty -Path $Root -Name "(Default)" -Value "URL:$Protocol Protocol"
    Set-ItemProperty -Path $Root -Name "URL Protocol" -Value ""
    
    $CmdPath = "$Root\shell\open\command"
    if (-not (Test-Path $CmdPath)) { New-Item -Path $CmdPath -Force }
    Set-ItemProperty -Path $CmdPath -Name "(Default)" -Value "`"$PdExe`" dial `"%1`""
    
    Write-Host "Registered $Protocol handler."
}

try {
    Register-Protocol "tel"
    Register-Protocol "sip"
    Write-Host "Success! tel: and sip: URIs will now open in PacketDial."
} catch {
    Write-Error "Failed to register protocols: $($_.Exception.Message)"
}

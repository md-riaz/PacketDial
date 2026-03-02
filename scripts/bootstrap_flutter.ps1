$ErrorActionPreference = "Stop"
Push-Location "app_flutter"

if (-not (Test-Path "windows")) {
  Write-Host "Generating Flutter project structure..."
  flutter create .
  Write-Host "Flutter project generated."
} else {
  Write-Host "Flutter windows/ directory already exists."
}

Pop-Location

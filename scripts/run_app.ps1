$ErrorActionPreference = "Stop"
Push-Location "app_flutter"
flutter pub get
flutter run -d windows
Pop-Location

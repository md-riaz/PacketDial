# Release Process

Guide for creating PacketDial release artifacts and managing versioning.

---

## Table of Contents

1. [Overview](#overview)
2. [Versioning](#versioning)
3. [Release Workflow](#release-workflow)
4. [Creating Release Artifacts](#creating-release-artifacts)
5. [Testing Releases](#testing-releases)
6. [Publishing](#publishing)

---

## Overview

PacketDial releases are distributed as **Windows x64 ZIP archives** containing:

```
PacketDial-windows-x64/
├── PacketDial.exe                      # Main executable
├── flutter_windows.dll                 # Flutter runtime
├── voip_core.dll                       # Rust core (required)
├── icudtl.dat                          # Unicode data
├── data/
│   └── flutter_assets/                 # UI assets
└── version.json                        # Version metadata
```

---

## Versioning

PacketDial uses **Semantic Versioning** (`MAJOR.MINOR.PATCH`):

- **MAJOR**: Breaking changes, major features
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes, minor improvements

### Version Storage

Version is stored in [`version.json`](../version.json) at the repository root:

```json
{
  "version": "0.8.0",
  "releaseDate": "2026-03-03",
  "channel": "stable",
  "minimumWindowsVersion": "10.1809"
}
```

Also referenced in:
- `app_flutter/pubspec.yaml`: `version: 0.8.0+build-number`
- `core_rust/Cargo.toml`: `version = "0.8.0"`

---

## Release Workflow

### 1. Plan the Release

Decide on version number based on recent commits:

```bash
# Check recent changes
git log --oneline v0.7.0..HEAD

# Examples:
#   - Bug fixes only         → 0.7.1 (PATCH)
#   - New features added     → 0.8.0 (MINOR)
#   - Breaking changes       → 1.0.0 (MAJOR)
```

### 2. Update Version Numbers

Update across all files:

```powershell
# Update version.json
$versionFile = "version.json"
$newVersion = "0.8.0"
$json = Get-Content $versionFile -Raw | ConvertFrom-Json
$json.version = $newVersion
$json.releaseDate = (Get-Date -Format "yyyy-MM-dd")
Set-Content $versionFile -Value ($json | ConvertTo-Json -Depth 10)

# Update app_flutter/pubspec.yaml
(Get-Content "app_flutter\pubspec.yaml") -replace '^version: .*$', "version: $newVersion+1" |
    Set-Content "app_flutter\pubspec.yaml"

# Update core_rust/Cargo.toml
(Get-Content "core_rust\Cargo.toml") -replace '^version = .*$', "version = `"$newVersion`"" |
    Set-Content "core_rust\Cargo.toml"
```

### 3. Update CHANGELOG

Edit [`CHANGELOG.md`](../CHANGELOG.md):

```markdown
## [0.8.0] — 2026-03-03

### Added
- Feature X
- Feature Y

### Fixed
- Bug fix #123
- Runtime issue with DLL loading

### Changed
- Updated PJSIP config for new audio codec
- Refactored Rust FFI bindings

### Security
- Fixed credential storage vulnerability

[Link to GitHub release]: https://github.com/md-riaz/PacketDial/releases/tag/v0.8.0
```

### 4. Commit & Tag

```bash
git add version.json app_flutter/pubspec.yaml core_rust/Cargo.toml CHANGELOG.md
git commit -m "Release: v0.8.0"

# Create annotated Git tag
git tag -a v0.8.0 -m "PacketDial v0.8.0 — New features"

# Push changes and tag
git push origin main
git push origin v0.8.0
```

---

## Creating Release Artifacts

### Prerequisites

Before building a release, ensure:

1. All code changes are committed and pushed
2. Tests pass (if CI configured)
3. Version numbers updated (see above)
4. Clean working directory: `git status` shows nothing

### Build Release DLL

```powershell
# (Ensure PJSIP is built first)
.\scripts\build_pjsip.ps1       # One-time if PJSIP changed

# Build Rust release DLL (automatically copies to app_flutter\windows\runner)
.\scripts\build_core.ps1 -Configuration Release

# Verify DLL was created
Test-Path "app_flutter\windows\runner\voip_core.dll"
```

### Build Flutter Release

```powershell
cd app_flutter

# Fetch dependencies
flutter pub get

# Clean previous builds
flutter clean

# Build Windows release
flutter build windows --release

# Build command details:
#  - Generates optimized native code
#  - Bundles all assets
#  - Links against release Rust DLL (via CMakeLists.txt)
# Duration: 5-15 minutes

cd ..
```

### Create Release Package

```powershell
# Run packaging script
.\scripts\package.ps1

# Output: dist\PacketDial-windows-x64.zip
# Size: typically 150-200 MB
```

**What `package.ps1` does:**

1. Reads `version.json` for version metadata
2. Copies entire Flutter release build output
3. Adds voip_core.dll (if present)
4. Validates required files exist:
   - `flutter_windows.dll`
   - `icudtl.dat`
   - `data/flutter_assets/`
5. Compresses everything into ZIP
6. Cleans up temporary staging directory

### Verify Release Package

```powershell
# Check ZIP contents
Expand-Archive "dist\PacketDial-windows-x64.zip" -DestinationPath "dist\verify" -Force

# Verify essential files
Test-Path "dist\verify\PacketDial-windows-x64\PacketDial.exe"
Test-Path "dist\verify\PacketDial-windows-x64\flutter_windows.dll"
Test-Path "dist\verify\PacketDial-windows-x64\voip_core.dll"
Test-Path "dist\verify\PacketDial-windows-x64\data\flutter_assets"

# Check size
(Get-Item "dist\PacketDial-windows-x64.zip").Length / 1MB

# Clean up
Remove-Item "dist\verify" -Recurse

# Result: Ready for distribution!
```

---

## Testing Releases

### Manual Testing

Before publishing, test the release package:

```powershell
# 1. Extract on clean test machine (or VM)
Expand-Archive "dist\PacketDial-windows-x64.zip" -DestinationPath "C:\PacketDial-Test"

# 2. Run the app
C:\PacketDial-Test\PacketDial-windows-x64\PacketDial.exe

# 3. Test key functionality:
#    - UI loads
#    - Add account (without real SIP, just tests database)
#    - Check Diagnostics screen for logs
#    - Close and reopen successfully
#    - Delete the app folder successfully
```

### Automated Testing (CI/CD)

The GitHub Actions CI pipeline (if configured) automatically:

1. Builds PJSIP
2. Builds Rust core
3. Builds Flutter app
4. Creates release package
5. Validates core functionality

**Trigger release builds:**

```bash
# GitHub Actions typically runs on:
# - Push to 'main' branch
# - Manual workflow dispatch
# - Git tag creation (v*.*.*)
```

---

## Publishing

### GitHub Releases

1. Go to https://github.com/md-riaz/PacketDial/releases
2. Click **"Draft a new release"**
3. Select tag: `v0.8.0`
4. Title: `PacketDial v0.8.0 — New Features`
5. Description: Copy from `CHANGELOG.md`
6. Attach files:
   - `dist/PacketDial-windows-x64.zip`
7. Click **"Publish release"**

### Download Instructions for Users

Add to release notes:

```markdown
## Install PacketDial v0.8.0

1. Download **PacketDial-windows-x64.zip** (see below)
2. Extract to a folder, e.g., `C:\PacketDial`
3. Run `PacketDial.exe`
4. (Optional) Create a shortcut to `PacketDial.exe` on your Desktop

### Requirements
- Windows 10 (Build 1809) or Windows 11, 64-bit
- .NET Desktop Runtime 6.0 or later (if not bundled)

### What's New in v0.8.0
- Feature X
- Bug fix Y
- Performance improvements

See [CHANGELOG.md](https://github.com/md-riaz/PacketDial/blob/main/CHANGELOG.md) for details.
```

### Additional Hosting (Optional)

- **Website**: Host ZIP on official website for direct download
- **Package Managers**: Publish to Chocolatey, Winget, etc. (advanced)
- **Auto-Update**: Implement in-app update checker (future)

---

## Post-Release Tasks

### 1. Update Documentation

- Update README badges to point to latest release
- Update download links on website
- Archive old release channels if needed

### 2. Create Next Development Version

```powershell
# Update version.json for next development cycle
$json = Get-Content "version.json" -Raw | ConvertFrom-Json
$json.version = "0.8.1-dev"  # or 0.9.0-dev, etc
Set-Content "version.json" -Value ($json | ConvertTo-Json -Depth 10)

git add version.json
git commit -m "Development: bump version to 0.8.1-dev"
git push origin main
```

### 3. Announce Release

- Post to forums, Discord, etc.
- Tweet/social media (if applicable)
- Email users (if mailing list exists)

### 4. Monitor for Issues

- Watch GitHub Issues and user feedback
- Be ready with patch releases (0.8.1, 0.8.2, etc.) for critical bugs
- Plan next features for MINOR/MAJOR update

---

## Troubleshooting Release Issues

### "Flutter build is slow"

```powershell
# Use parallel jobs (if available)
flutter build windows --release --split-debug-info

# Or, skip unused platforms
flutter build windows --release --no-tree-shake-icons
```

### "Package.ps1 fails to find DLL"

```powershell
# Verify DLL exists
ls "core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll"

# If missing, rebuild
.\scripts\build_core.ps1

# Then retry
.\scripts\package.ps1
```

### "ZIP is too large"

Check what's taking space:

```powershell
# List largest files in staging
Get-ChildItem -Path "app_flutter\build\windows\x64\runner\Release" -Recurse |
    Sort-Object -Property Length -Descending |
    Select-Object -First 20 FullName, @{Name="Size(MB)"; Expression={[math]::Round($_.Length/1MB,2)}}
```

Possible causes:
- Debug symbols in DLL (use release build)
- Unused assets (trim `pubspec.yaml`)
- Large flutter_windows.dll (unavoidable; inherent to Flutter Windows)

---

## See Also

- [Quick Start](quickstart.md) — For users installing a release
- [Windows Setup Guide](windows_setup_guide.md) — Full build guide for developers
- [CHANGELOG.md](../CHANGELOG.md) — Release notes and plan

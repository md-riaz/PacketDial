# Release Process

Current release flow for PacketDial.

## Version Source of Truth

PacketDial no longer uses `version.json`.

Current version sources:

- Flutter runtime/app version: [`app_flutter/pubspec.yaml`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/pubspec.yaml)
- Rust crate version: [`core_rust/Cargo.toml`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/Cargo.toml)

The release workflow updates both directly.

## Release Artifacts

The repo currently produces:

- portable ZIP package
- Windows installer

Relevant files:

- [`scripts/package.ps1`](/C:/Users/vm_user/Downloads/PacketDial/scripts/package.ps1)
- [`scripts/build_package.ps1`](/C:/Users/vm_user/Downloads/PacketDial/scripts/build_package.ps1)
- [`scripts/build_installer.ps1`](/C:/Users/vm_user/Downloads/PacketDial/scripts/build_installer.ps1)
- [`scripts/build_all.ps1`](/C:/Users/vm_user/Downloads/PacketDial/scripts/build_all.ps1)
- [`.github/workflows/release.yml`](/C:/Users/vm_user/Downloads/PacketDial/.github/workflows/release.yml)

## Manual Release Workflow

### 1. Pick the release version

PacketDial follows semantic versioning:

- `MAJOR`: breaking changes
- `MINOR`: new backward-compatible features
- `PATCH`: fixes and small improvements

### 2. Update versions

Update:

- `app_flutter/pubspec.yaml`
- `core_rust/Cargo.toml`
- optionally `CHANGELOG.md`

### 3. Build dependencies and binaries

```powershell
.\scripts\build_pjsip.ps1
.\scripts\build_core.ps1 -Configuration Release
cd app_flutter
flutter pub get
flutter build windows --release
cd ..
```

### 4. Create artifacts

```powershell
.\scripts\package.ps1
.\scripts\build_package.ps1 -Version 1.0.0
.\scripts\build_installer.ps1 -Version 1.0.0
```

### 5. Verify outputs

Check `dist/` for:

- `PacketDial-windows-x64.zip`
- `PacketDial-<version>-Portable.zip`
- `PacketDial-Setup-<version>.exe`

## What `package.ps1` Does

`package.ps1`:

1. reads the version from `app_flutter/pubspec.yaml`
2. collects Flutter Windows release output
3. copies `voip_core.dll` if present
4. copies `pd.exe` if present
5. validates Flutter runtime files such as `flutter_windows.dll`, `icudtl.dat`, and `data/app.so`
6. writes the ZIP package into `dist/`

## CI Release Workflow

The GitHub release workflow:

1. validates the requested semver input
2. updates `app_flutter/pubspec.yaml`
3. updates `core_rust/Cargo.toml`
4. builds the Windows app
5. creates the portable ZIP and installer
6. uploads artifacts
7. creates the GitHub release

See:

- [`.github/workflows/release.yml`](/C:/Users/vm_user/Downloads/PacketDial/.github/workflows/release.yml)

## Notes

- If docs or scripts still mention `version.json`, those references are stale.
- Runtime version display in the app is provided through `PackageInfo`, not a repo-level manifest file.

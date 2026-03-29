# PacketDial

PacketDial is a Windows SIP softphone built with:

- PJSIP for SIP/media
- Rust for the native engine layer (`voip_core.dll`)
- Flutter Desktop for the UI

## Quick Links

### Start Here

- [Developer Guide](docs/developer-guide.md)
- [Architecture](docs/architecture.md)
- [FFI API](docs/FFI_API.md)
- [Build and Install](docs/BUILD_AND_INSTALL.md)
- [Developer Workflow](docs/dev-workflow.md)

### Component Docs

- [Flutter App](docs/flutter-app.md)
- [Rust Core](docs/rust-core.md)
- [PJSIP Build](docs/pjsip-build.md)
- [Release Process](docs/release-process.md)
- [Features](docs/FEATURES.md)

## Current Product Shape

- Multi-account SIP registration
- Dialer with account dropdown for outgoing calls
- Incoming call banner and dialer takeover
- Hold, mute, DTMF, transfer, and conference
- BLF contacts and presence filtering
- Global DND with footer toggle
- Local call recording to WAV
- Settings, integrations, diagnostics, and packaging

## Repo Structure

| Path | Purpose |
|------|---------|
| `app_flutter/` | Flutter desktop app |
| `core_rust/` | Rust engine DLL and PJSIP shim |
| `engine_pjsip/` | vendored PJSIP source |
| `scripts/` | setup, build, packaging, and run scripts |
| `installer/` | Inno Setup resources |
| `docs/` | project documentation |
| `tools/` | auxiliary tools such as the CLI |

## Build

### First-time setup

```powershell
.\scripts\setup_windows.ps1
```

### Build native dependencies

```powershell
.\scripts\build_pjsip.ps1
.\scripts\build_core.ps1 -Configuration Debug
```

### Run the app

```powershell
.\scripts\run_app.ps1
```

## Test

### Flutter

```powershell
cd app_flutter
flutter analyze
flutter test
```

### Rust

```powershell
cd core_rust
cargo build
cargo test --lib
```

## Important Current Notes

- Call history is persisted by Flutter, not exported from Rust.
- DND is global, not per-account.
- Local recording is native WAV capture only.
- If no recording folder is configured, recordings fall back to `Desktop\Recordings`.
- `version.json` is no longer part of the release flow.

## Recommended Reading Order

1. [Developer Guide](docs/developer-guide.md)
2. [Architecture](docs/architecture.md)
3. [Flutter App](docs/flutter-app.md)
4. [Rust Core](docs/rust-core.md)
5. [FFI API](docs/FFI_API.md)

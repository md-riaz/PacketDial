# Open Source Windows SIP Client

PacketDial is a modern, developer-grade Windows SIP softphone built with:
- **PJSIP** (C) as the SIP/RTP engine
- **Rust** core wrapper compiled as a cdylib (`voip_core.dll`) exposing a C ABI
- **Flutter Desktop** UI calling Rust via Dart FFI

---

## Repo layout

| Directory | Contents |
|-----------|----------|
| `engine_pjsip/` | PJSIP source (add as submodule or extract pjproject here) |
| `core_rust/` | Rust cdylib — command/event channel, state machines |
| `app_flutter/` | Flutter Windows app (5-screen UI) |
| `scripts/` | Build & packaging scripts |
| `docs/` | Architecture, FFI API reference, product spec |
| `dist/` | Packaging output (`PacketDial-windows-x64.zip`) |

---

## Windows setup & build

> **New to this repo?** See the [Windows Setup Guide](docs/windows_setup_guide.md) for a
> full walkthrough with the one-click setup script.

### One-click build (fresh Windows 10/11 VM)

```powershell
# 1. Clone
git clone --recurse-submodules https://github.com/md-riaz/PacketDial
cd PacketDial

# 2. Run the setup script (elevated PowerShell)
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\setup_windows.ps1
# → installs Git, VS Build Tools, Rust, Flutter, then builds & packages the app
# → output: dist\PacketDial-windows-x64.zip
```

### Prerequisites (if installing tools manually)

- [Visual Studio Build Tools 2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) — Desktop development with C++ workload
- [Rust stable](https://rustup.rs) — `rustup target add x86_64-pc-windows-msvc`
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/desktop) (stable, 3.41.2) — `flutter config --enable-windows-desktop`
- Git

### Quick start (tools already installed)

```powershell
# Skip tool installation, just build
.\scripts\setup_windows.ps1 -SkipInstall
```

### Hot-reload development

The `run_app.ps1` script automatically builds the Rust core in debug mode and launches Flutter with hot-reload:

```powershell
.\scripts\run_app.ps1
```

**Manual workflow:**
```powershell
# Build Rust core in debug mode (faster compilation)
cd core_rust
cargo build --target x86_64-pc-windows-msvc

# Or use the helper script
.\scripts\build_core_debug.ps1

# Run Flutter with hot-reload
cd app_flutter
flutter run -d windows
```

The CMake build system automatically copies `voip_core.dll` from the correct location (debug or release) based on your build configuration.

---

## CI badges

| Workflow | Status |
|----------|--------|
| Rust core (Linux) | [![rust-ci](https://github.com/md-riaz/PacketDial/actions/workflows/rust-ci.yml/badge.svg)](https://github.com/md-riaz/PacketDial/actions/workflows/rust-ci.yml) |
| Windows build | [![windows-ci](https://github.com/md-riaz/PacketDial/actions/workflows/windows-ci.yml/badge.svg)](https://github.com/md-riaz/PacketDial/actions/workflows/windows-ci.yml) |

---

## Architecture

```
Flutter Desktop UI
    ↕  JSON commands / events (50 ms poll)
EngineChannel (Dart)
    ↕  Dart FFI  (engine_send_command / engine_poll_event / engine_free_string)
voip_core.dll  (Rust)
    ↕  TODO: C FFI
PJSIP (C)
```

See [`docs/architecture.md`](docs/architecture.md) and [`docs/FFI_API.md`](docs/FFI_API.md).

---

## Milestones

| Milestone | Status |
|-----------|--------|
| M0 - Build System | ✅ Done |
| M1 - Registration | ✅ Done |
| M2 - Calling | ✅ Done |
| M3 - Diagnostics | ✅ Done |
| M4 - Packaging | ✅ Done |
| M5 - Windows Build | ✅ Done |
| M6 - Hardening & TLS | ✅ Done |
| M7 - PJSIP Integration | 🔄 In Progress |


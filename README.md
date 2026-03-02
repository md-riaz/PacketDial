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

## Prerequisites (Windows)

- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) (C++ workload)
- [Rust stable](https://rustup.rs) — `rustup target add x86_64-pc-windows-msvc`
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/desktop) (stable channel) — `flutter config --enable-windows-desktop`
- Git

---

## Quick start

```powershell
# 1. Clone (pjproject as submodule optional until M5)
git clone --recurse-submodules https://github.com/md-riaz/PacketDial

# 2. Build Rust core
cd core_rust
cargo build --release        # produces target/release/voip_core.dll

# 3. Copy DLL to Flutter
cd ..\app_flutter
flutter pub get
flutter run -d windows       # hot-reload development
```

### To build a release package

```powershell
# From repo root:
cd core_rust && cargo build --release && cd ..
cd app_flutter && flutter build windows --release && cd ..
.\scripts\package.ps1        # → dist\PacketDial-windows-x64.zip
```

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
| M6 - Hardening & TLS | 🔲 Planned |


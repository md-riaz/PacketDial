# Open Source Windows SIP Client

PacketDial is a modern, developer-grade Windows SIP softphone built with:
- **PJSIP** (C) as the SIP/RTP engine
- **Rust** core wrapper compiled as a cdylib (`voip_core.dll`) exposing a C ABI
- **Flutter Desktop** UI calling Rust via Dart FFI

---

## Quick Links

**New to PacketDial?**
- [Quick Start](docs/quickstart.md) — Get running in 5 minutes (one-click setup)
- [Windows Setup Guide](docs/windows_setup_guide.md) — Detailed installation walkthrough
- [Troubleshooting](docs/troubleshooting.md) — Solutions to common issues

**Active Development?**
- [Developer Workflow](docs/dev-workflow.md) — Hot-reload setup and daily workflows
- [Rust Core Guide](docs/rust-core.md) — Building and FFI integration
- [PJSIP Build Guide](docs/pjsip-build.md) — PJSIP compilation details
- [Flutter App Guide](docs/flutter-app.md) — Windows desktop setup

**Release & Distribution?**
- [Release Process](docs/release-process.md) — Versioning and artifact creation

**Architecture & Design?**
- [Architecture](docs/architecture.md) — System overview and component interaction
- [FFI API](docs/FFI_API.md) — Complete C interface reference
- [Design Decisions](docs/adr/) — Architecture decision records

---

## Quick Start

### One-click build (fresh Windows 10/11)

```powershell
git clone --recurse-submodules https://github.com/md-riaz/PacketDial
cd PacketDial
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\setup_windows.ps1
```

**Duration:** 20–40 minutes (first run)  
**Output:** `dist\PacketDial-windows-x64.zip`

See [Quick Start](docs/quickstart.md) for more details and options.

---

## How to Run (Development)

The fastest way to launch PacketDial for active development is the **hot-reload script:**

```powershell
# From the repository root
.\scripts\run_app.ps1
```

This single command will:
1. Build the Rust core (`voip_core.dll`) in **debug mode** (~30–60 seconds)
2. Copy the DLL to Flutter's debug output directory
3. Launch the Flutter desktop app with **hot-reload** enabled

> **Prerequisite:** PJSIP must be built first. See [How to Build](#how-to-build-release) Step 1.

Once the app is running:
- Press **`r`** → hot-reload Dart/Flutter code changes instantly
- Press **`R`** → full restart (rebuilds Rust + reloads Flutter)
- Press **`q`** → quit


### Manual Run (Step-by-Step)

If you prefer to run each step manually:

```powershell
# 1. Build Rust core DLL (debug mode)
.\scripts\build_core.ps1 -Configuration Debug

# 2. Run Flutter app
cd app_flutter
flutter pub get
flutter run -d windows
```

---

## How to Build (Release)

### Prerequisites

| Requirement | Details |
|-------------|---------|
| **OS** | Windows 10 (build 1809+) or Windows 11, 64-bit |
| **Visual Studio Build Tools 2022** | Desktop development with C++ workload |
| **Rust** | Stable toolchain (auto-installed by `setup_windows.ps1`) |
| **Flutter SDK** | 3.41.2+ (auto-installed by `setup_windows.ps1`) |
| **Disk Space** | 10+ GB free |

> **Tip:** Running `.\scripts\setup_windows.ps1` installs all prerequisites automatically.

### Step 1: Build PJSIP

```powershell
.\scripts\build_pjsip.ps1
```

This compiles the PJSIP C library from source. PJSIP is **required** for the app to function.

### Step 2: Build the Rust Core DLL

```powershell
# Release mode (optimized, ~1-3 minutes)
.\scripts\build_core.ps1 -Configuration Release

# Debug mode (faster compile, ~30-60 seconds)
.\scripts\build_core.ps1 -Configuration Debug
```

**Output:** `core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll`

### Step 3: Build the Flutter App

```powershell
cd app_flutter
flutter pub get
flutter build windows --release
```

**Output:** `app_flutter\build\windows\x64\runner\Release\`

### Step 4: Package for Distribution

```powershell
.\scripts\package.ps1
```

Creates a distributable ZIP at `dist\PacketDial-windows-x64.zip` containing:
- `PacketDial.exe` (Flutter desktop app)
- `voip_core.dll` (Rust SIP engine)
- Flutter runtime files (`flutter_windows.dll`, `icudtl.dat`, `data/`)

---

## How to Test

### Rust Core Tests

```powershell
cd core_rust
cargo test
```

### Flutter Tests

```powershell
cd app_flutter
flutter test
```

### Lint (Rust)

```powershell
cd core_rust
cargo clippy -- -D warnings
```

---

## Directory Structure

| Directory | Contents |
|-----------|----------|
| `engine_pjsip/` | PJSIP source (vendored pjproject 2.14.1) |
| `core_rust/` | Rust FFI wrapper → `voip_core.dll` |
| `app_flutter/` | Flutter Windows desktop UI (5 screens) |
| `scripts/` | Build & deployment automation |
| `docs/` | Architecture, API reference, guides |
| `dist/` | Release artifacts (ZIP files) |

---

## Known Limitations / TODOs

- **Call transfer:** Not yet implemented (PJSIP `pjsua_call_xfer` integration pending)
- **Conference calling:** Multi-party bridging not yet wired
- **TLS/SRTP:** Config flags exist in PJSIP but are not surfaced in the UI
- **Credential persistence:** Currently in-memory only — Windows Credential Manager integration planned
- **Audio device hot-swap:** Device list is static at startup; runtime refresh not yet supported
- **Linux / macOS builds:** Only Windows x64 is supported at this time

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
    ↕  Direct C ABI (engine_register / engine_make_call / engine_hangup)
EngineChannel (Dart)
    ↕  Direct FFI (engine_register / engine_make_call / engine_hangup / engine_set_event_callback)
voip_core.dll  (Rust)
    ↕  C shim FFI (pd_init / pd_acc_add / pd_call_make / ...)
PJSIP (C)
```

See [`docs/architecture.md`](docs/architecture.md) and [`docs/FFI_API.md`](docs/FFI_API.md).

---

## FFI API

PacketDial uses a **Direct C ABI** for all communication between Dart and Rust. This ensures high performance and type safety without the overhead of JSON parsing for every command.

See [`docs/FFI_API.md`](docs/FFI_API.md) for complete C ABI signatures and event details.

### Account Model (Spec v2.1)

Accounts are identified by an internal **UUID**.

| Field | Purpose |
|-------|---------|
| `accountName` | User-friendly label (e.g., "Office", "Home") |
| `username` | SIP Authentication ID |
| `password` | SIP Password |
| `domain` | SIP Domain / Registrar (e.g., `sip.provider.com`) |
| `sipProxy` | (Optional) Outbound proxy |
| `authUsername` | (Optional) Separate authorization name |
| `transport` | `UDP` (default) or `TCP` |
| `tls_enabled` | Boolean flag for SIPS/TLS |

---

## 🛠️ Build & CI/CD Scripts

Located in [`scripts/`](file:///c:/Users/vm_user/Downloads/PacketDial/scripts/):

| Script | Purpose |
|--------|---------|
| `setup_windows.ps1` | **Full Setup**: Prerequisites + PJSIP + Rust + Flutter |
| `run_app.ps1` | **Dev Inner Loop**: Rebuilds Rust (debug) + Flutter Run |
| `build_core.ps1` | **Rust Core**: Build DLL (`-Configuration Debug\|Release`) |
| `build_pjsip.ps1` | **PJSIP Library**: Compiles PJSIP from source |
| `package.ps1` | **Dist**: Creates Windows x64 ZIP release |

---

## Milestones

| Milestone | Status | Notes |
|-----------|--------|-------|
| M0 - Build System | ✅ Done | CI, CMake, Rust cdylib, Flutter Windows desktop |
| M1 - Registration | ✅ Done | Account model, command/event channel, stub SIP registration |
| M2 - Calling | ✅ Done | Dialer UI, call state machine, hold/mute/hangup (stub) |
| M3 - Diagnostics | ✅ Done | SIP capture + log masking, media stats, export bundle |
| M4 - Packaging | ✅ Done | `scripts/package.ps1`, GitHub Release workflow |
| M5 - Windows Build | ✅ Done | CI build with PJSIP cache, `subst X:` workaround |
| M6 - Hardening & TLS | ✅ Done | TLS/SRTP flags, credential store, `cargo clippy -D warnings` |
| M7 - PJSIP Integration | ✅ Done | C shim + Rust FFI: real SIP registration, outgoing/incoming calls, audio, SIP capture |
| M8 - FFI Standardization | ✅ Done | Direct C ABI functions (`engine_register`, `engine_make_call`, `engine_hangup`, `engine_set_event_callback`), structured event callbacks, Dart/Rust test suites |

> **Note:** PJSIP is required for all SIP functionality. Build it with `scripts/build_pjsip.ps1`
> before compiling the Rust core. The thin C shim (`pjsip_shim.c`) bridges PJSIP and the Rust FFI layer.


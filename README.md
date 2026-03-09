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
- [Release Guide](docs/RELEASE_GUIDE.md) — GitHub release workflow instructions

**Architecture & Design?**
- [Architecture](docs/architecture.md) — System overview and component interaction
- [FFI API](docs/FFI_API.md) — Complete C interface reference
- [Design Decisions](docs/adr/) — Architecture decision records

---

## Quick Start

### For End Users (Download & Install)

**Option 1: Windows Installer (Recommended)**
```powershell
# Download PacketDial-Setup-X.X.X.exe from Releases
# Run the installer
# Launch PacketDial from Start Menu
```

**Option 2: Portable Version**
```powershell
# Download PacketDial-X.X.X-Portable.zip from Releases
# Extract to any folder (e.g., C:\Program Files\PacketDial)
# Run PacketDial.exe
```

See [Build & Installation Guide](docs/BUILD_AND_INSTALL.md) for detailed instructions.

### For Developers (Build from Source)

**One-click build (fresh Windows 10/11)**
```powershell
git clone --recurse-submodules https://github.com/md-riaz/PacketDial
cd PacketDial
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\setup_windows.ps1
```

**Complete build with installer:**
```powershell
.\scripts\build_all.ps1 -Version 1.0.0
```

**Duration:** 20–40 minutes (first run)  
**Output:** `dist\PacketDial-Setup-1.0.0.exe` + `dist\PacketDial-1.0.0-Portable.zip`

See [Build & Installation Guide](docs/BUILD_AND_INSTALL.md) for detailed instructions.

---

## Key Features

### 📞 Call Management
- **Multi-Account Support** - Multiple SIP accounts simultaneously
- **Account Selection** - Choose account per outgoing call
- **Call Transfer** - Blind or attended (consult) transfer
- **3-Way Conference** - Merge two calls into conference
- **Call Hold/Mute** - Standard call controls
- **Call History** - Complete call tracking

### 👥 Contacts & Presence
- **BLF Contacts** - Real-time presence monitoring
- **Presence States** - Available/Busy/Ringing/Unknown
- **Contact Filtering** - Filter by presence state
- **Quick Dial** - One-click calling from contacts
- **Import/Export** - Backup contacts to JSON

### ⚙️ Settings & Configuration
- **Unified Settings** - All settings in one place
- **Codec Selection** - Drag-to-reorder priority
- **Do Not Disturb** - Auto-reject calls (with footer toggle)
- **Auto Answer** - Automatically answer calls
- **DTMF Method** - In-band/RFC2833/SIP INFO
- **Call Forwarding** - Per-account forwarding rules
- **Caller Lookup** - Custom URL for caller ID

### 📦 Distribution
- **Windows Installer** - Professional setup (Inno Setup)
- **Portable Version** - No installation required
- **File-Based Settings** - Easy backup (`%APPDATA%\PacketDial\`)

See [Complete Features List](docs/FEATURES.md) for detailed documentation.

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

## Integration & Automation (Built-in)

PacketDial is designed for business-grade integration. It includes a built-in controller and event broadcasting system.

### 1. CLI Controller (`pd.exe`)
Control the running softphone from any terminal, script, or CRM.
```powershell
pd dial 100                 # Intelligently picks an account and dials
pd answer                   # Answers first ringing call
pd hangup                   # Ends active call
pd events                   # Streams real-time VoIP events (JSON)
```

### 2. Protocol Handlers (`tel:` and `sip:`)
PacketDial registers as the system default for standard VoIP links.
- Click a phone number in Chrome, Outlook, or your CRM.
- Instant dial via the running PacketDial instance (powered by the CLI bridge).
- Run `.\scripts\register_protocols.ps1` to enable.

### 3. Event Broadcasting (Named Pipes)
Subscribe to real-time events via `\\.\pipe\PacketDial.API`.
- **Multiple Subscribers:** Multiple external tools can listen simultaneously.
- **Zero Latency:** Direct IPC access to SIP registration and call-state changes.
- See [Integration Guide](docs/integration.md) for full JSON API details.

---

## How to Build (Release)

### Prerequisites

| Requirement | Details |
|-------------|---------|
| **OS** | Windows 10 (build 1809+) or Windows 11, 64-bit |
| **Visual Studio Build Tools 2022** | Desktop development with C++ workload |
| **Rust** | Stable toolchain (auto-installed by `setup_windows.ps1`) |
| **Flutter SDK** | 3.41.4+ (auto-installed by `setup_windows.ps1`) |
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
| `app_flutter/` | Flutter Windows desktop UI |
| `app_flutter/lib/screens/` | 5 main screens (Dialer, Contacts, History, Accounts, Settings) |
| `scripts/` | Build automation (build_all.ps1, build_installer.ps1, etc.) |
| `docs/` | Complete documentation |
| `dist/` | Release artifacts (installer + portable ZIP) |
| `assets/` | Application assets and icons |

### Documentation Files

| File | Description |
|------|-------------|
| [FEATURES.md](docs/FEATURES.md) | Complete feature list with status |
| [BUILD_AND_INSTALL.md](docs/BUILD_AND_INSTALL.md) | Build and installation guide |
| [QUICKSTART.md](docs/quickstart.md) | 5-minute setup guide |
| [ARCHITECTURE.md](docs/architecture.md) | System architecture overview |
| [FFI_API.md](docs/FFI_API.md) | Rust FFI API reference |

---

## Known Limitations / TODOs

### ✅ Implemented (v1.0)
- **Multi-Account Support** - Multiple SIP accounts with selection
- **Call Transfer** - Blind and attended transfer
- **3-Way Conference** - Merge two calls
- **BLF/Presence** - File-based contacts with presence
- **Unified Settings** - All settings in one page
- **DND** - App-wide with footer toggle
- **Call Forwarding** - Per-account
- **Caller Lookup** - Custom URL per account
- **Codec Selection** - App-wide priority
- **Auto Answer** - App-wide
- **DTMF Method** - App-wide selection
- **Packaging** - Installer + Portable versions

### ⏳ In Progress
- **Windows Credential Manager** - Secure password storage (currently in-memory)
- **Audio Device Hot-Swap** - Runtime device refresh (requires restart)
- **Multiple Active Calls UI** - Backend ready, UI needs enhancement
- **Call Recording** - Backend hooks ready, UI pending

### 🔜 Planned
- **Video Calls** - SIP video support
- **Instant Messaging** - SIP SIMPLE
- **Conference Bridge** - 5+ party conferences
- **Linux/macOS** - Cross-platform builds
- **Mobile Apps** - iOS/Android Flutter apps

See [Features](docs/FEATURES.md) for complete implementation status.

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

| Milestone | Status | Description |
|-----------|--------|-------------|
| M0 - Build System | ✅ Done | CI, CMake, Rust cdylib, Flutter Windows desktop |
| M1 - Registration | ✅ Done | Account model, command/event channel, stub SIP registration |
| M2 - Calling | ✅ Done | Dialer UI, call state machine, hold/mute/hangup |
| M3 - Diagnostics | ✅ Done | SIP capture + log masking, media stats, export bundle |
| M4 - Packaging | ✅ Done | Installer + portable ZIP, GitHub Release workflow |
| M5 - Windows Build | ✅ Done | CI build with PJSIP cache, `subst X:` workaround |
| M6 - Hardening & TLS | ✅ Done | TLS/SRTP flags, credential store, `cargo clippy -D warnings` |
| M7 - PJSIP Integration | ✅ Done | C shim + Rust FFI: real SIP registration, calls, audio, capture |
| M8 - FFI Standardization | ✅ Done | Direct C ABI functions, structured events, test suites |
| M9 - Advanced Features | ✅ Done | Transfer, conference, BLF, DND, forwarding, multi-account |
| M10 - Packaging System | ✅ Done | Inno Setup installer, portable ZIP, build automation |

> **Note:** PJSIP is required for all SIP functionality. Build it with `scripts/build_pjsip.ps1`
> before compiling the Rust core. The thin C shim (`pjsip_shim.c`) bridges PJSIP and the Rust FFI layer.

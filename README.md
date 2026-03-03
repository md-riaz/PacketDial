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

### Hot-reload development

```powershell
.\scripts\run_app.ps1
```

Builds Rust core in debug mode and launches Flutter with live reload.  
See [Developer Workflow](docs/dev-workflow.md) for workflows and tips.

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

## Detailed Build & Setup

For complete build instructions, see:
- [Quick Start](docs/quickstart.md) — Faster (5 min)
- [Windows Setup Guide](docs/windows_setup_guide.md) — Detailed (20-40 min)

Prerequisites:
- Windows 10 (build 1809+) or Windows 11, 64-bit
- Visual Studio Build Tools 2022 (Desktop development with C++)
- Rust stable (auto-installed by setup script)
- Flutter SDK 3.41.2 (auto-installed by setup script)
- 10+ GB free disk space

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

> **Note:** M1–M6 deliver the full architecture and UI with a stub engine (no PJSIP libs needed).
> M7 wires real SIP by compiling a thin C shim against pjsua when PJSIP static libs are present
> (built by `scripts/build_pjsip.ps1`).  Without PJSIP, the DLL falls back to the stub behaviour,
> keeping the app functional for development and testing without a full PJSIP build.


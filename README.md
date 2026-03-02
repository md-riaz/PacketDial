# Open Source Windows SIP Client (Monorepo Scaffold)

Generated: 2026-03-02T03:39:35.016847 UTC

This is a GitHub-ready starter scaffold for a modern open-source Windows SIP softphone:
- **PJSIP** (C) as the SIP/RTP engine (built as static libs)
- **Rust** core wrapper compiled as a **cdylib** (DLL) exposing a small C ABI for Flutter
- **Flutter Desktop** UI calling Rust via **Dart FFI**

## Repo layout
- `engine_pjsip/` : PJSIP source lives here (see below)
- `core_rust/`    : Rust DLL with C ABI
- `app_flutter/`  : Flutter Windows app
- `scripts/`      : build scripts
- `docs/`         : dev docs

## Quick start (Windows)
1. Install prerequisites:
   - Visual Studio Build Tools (C++)
   - Rust (stable)
   - Flutter SDK
   - Git

2. Put pjproject source into:
   - `engine_pjsip/pjproject/`
   (either as a git submodule or by downloading pjproject and extracting there)

3. Build PJSIP:
   - PowerShell: `./scripts/build_pjsip.ps1`

4. Build Rust core:
   - `./scripts/build_core.ps1`

5. Run Flutter app:
   - `./scripts/run_app.ps1`

The Flutter app will load the Rust DLL and show engine status.

> Note: This scaffold wires the build plumbing and FFI bridge. SIP calling is not implemented yet.

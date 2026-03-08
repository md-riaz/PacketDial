# Developer Workflow Guide

This guide covers day-to-day development patterns for PacketDial contributors.

---

## Table of Contents

1. [Hot-Reload Development](#hot-reload-development)
2. [Script Reference](#script-reference)
3. [Debugging](#debugging)
4. [Common Workflows](#common-workflows)
5. [Build Configuration](#build-configuration)

---

## Hot-Reload Development

### Quick Start

```powershell
.\scripts\run_app.ps1
```

This builds Rust in debug mode (~30 seconds) and launches Flutter with hot-reload enabled.

### Workflow

1. **Edit Dart/Flutter code**
   - Modify `.dart` files in `app_flutter/lib/`
   - Press `r` in the Flutter terminal to hot-reload instantly (no rebuild needed)
   - Changes appear in the running app

2. **Edit Rust code**
   - Modify `.rs` files in `core_rust/src/`
   - Press `R` in the Flutter terminal to hot-restart:
     - Rust code recompiles (debug mode, ~30-60 seconds)
     - DLL is reloaded
     - App hot-reloads
   - This is faster than stopping/restarting manually

3. **Edit FFI signatures or C interop**
   - Both Dart and Rust FFI definitions must match
   - After changing FFI, press `R` for restart
   - If issues occur, press `q` and restart with `.\scripts\run_app.ps1`

### Performance Tips

- **Debug mode** (~30 seconds): Use for development, hot-reload
- **Release mode** (~1–3 minutes): Use for performance testing, release
- **Incremental builds**: Rust caches incrementally; only changed files recompile
- **CMake caching**: Flutter's CMake build system caches between runs

---

## Script Reference

### Daily Commands

| Script | Purpose | Time | Use When |
|--------|---------|------|----------|
| `run_app.ps1` | Hot-reload dev | ~30 sec | Active development |
| `build_core_debug.ps1` | Rust (debug only) | ~30 sec | Quick test without Flutter |
| `build_core.ps1` | Rust (release) | ~1-3 min | Performance testing, release prep |

### Occasional Commands

| Script | Purpose | Time | Use When |
|--------|---------|------|----------|
| `setup_windows.ps1 -SkipInstall` | Rebuild all (skip tool install) | ~20 min | Code review, CI verification |
| `build_pjsip.ps1` | Rebuild PJSIP libs | ~5-20 min | PJSIP source changes (rare) |
| `package.ps1` | Create release ZIP | ~1 min | Release build complete |

---

## Debugging

### Dart/Flutter Debugging

Use VS Code or Android Studio with the official [Dart extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.dart-code).

Features:
- Breakpoints in Dart code
- Inspect variables, call stack
- Evaluate expressions in console

### Rust Debugging

For Windows x64 native debugging, use **WinDbg** (if needed):

```powershell
# Build with debug symbols (default in debug mode)
cargo build --target x86_64-pc-windows-msvc

# Attach WinDbg to PacketDial.exe process
windbg app_flutter\build\windows\x64\runner\Debug\PacketDial.exe
```

Alternatively, add `eprintln!()` macros to Rust code for logging to the debug terminal.

### Logs & Diagnostics

PacketDial includes a diagnostics screen (in the UI) that captures:
- SIP transaction logs
- Media statistics
- Event history

Logs are masked (credentials redacted) before export.

---

### SIP Runtime Triage (Registration + Calling)

Use this when debugging account registration, transport issues, and call setup failures:

1. Set engine log level to `Debug` from Diagnostics.
2. Register one or more accounts and confirm `RegistrationStateChanged` events.
3. Place a call from Flutter dialer and from CLI (`pd dial ...`) to compare behavior.
4. Inspect logs for:
   - `CallStart: normalized target ...`
   - `CallStart: audio preflight ...`
   - `pd_call_make preflight`
5. Verify `selected_input`/`selected_output` IDs in logs exist in `AudioDeviceList`.

This confirms the full chain: Flutter input -> Rust command normalization -> PJSIP media/device preflight.

Terminal-only probes:

```powershell
cd app_flutter
# Single account register + call target probe
dart run bin/sip_probe.dart --server <host:port> --username <user> --password <pass> --transport udp --dial 127

# Two-account registration in one engine session
dart run bin/sip_probe.dart --server <host:port> --username <user> --password <pass> --transport udp --multi-two
```

## Common Workflows

### Adding a New Command

1. **Dart side** (`app_flutter/lib/core/engine_channel.dart`):
   ```dart
   Future<String> sendCommand(String cmd, Map<String, dynamic> params) async {
     return _channel.invokeMethod('sendCommand', {'cmd': cmd, 'params': params});
   }
   ```

2. **Rust side** (`core_rust/src/lib.rs`):
   ```rust
   /// Handle incoming command
   pub fn handle_command(cmd: &str, params: serde_json::Value) -> Result<String> {
       match cmd {
           "my_command" => { /* implementation */ },
           _ => Err("Unknown command".into()),
       }
   }
   ```

3. **Test it**:
   ```powershell
   Press 'r' to hot-reload  # Dart changes
   Press 'R' to hot-restart # Rust changes
   ```

### Building with PJSIP

PJSIP is required. Build it before compiling the Rust core:

1. Build PJSIP:
   ```powershell
   .\scripts\build_pjsip.ps1   # ~5-20 min (one-time)
   ```

2. Rebuild Rust (PJSIP libs are auto-detected):
   ```powershell
   .\scripts\build_core.ps1   # or run 'R' in Flutter terminal
   ```

The Rust `build.rs` script automatically:
- Detects PJSIP libs at `engine_pjsip/build/out/lib/`
- Links C shim against PJSIP static libs

---

## Build Configuration

### Cargo Flags

```powershell
# Debug mode (default, fastest)
cargo build --target x86_64-pc-windows-msvc

# Release mode (optimized)
cargo build --release --target x86_64-pc-windows-msvc

# With PJSIP (detected automatically if libs present)
$env:PJSIP_LIB_DIR = "engine_pjsip\build\out\lib"
$env:PJSIP_INCLUDE_DIR = "engine_pjsip\build\out\include"
cargo build --release --target x86_64-pc-windows-msvc
```

### Flutter Configuration

```powershell
# Enable Windows Desktop support (one-time)
flutter config --enable-windows-desktop

# Switch between debug and release
flutter run -d windows           # Debug (default)
flutter build windows            # Debug build
flutter build windows --release  # Release build

# Run on a specific device
flutter devices                  # List available devices
flutter run -d windows           # Run on Windows desktop
```

### Environment Variables

Set these before building Rust if using custom PJSIP paths:

```powershell
$env:PJSIP_LIB_DIR = "<path-to-libs>"
$env:PJSIP_INCLUDE_DIR = "<path-to-headers>"
```

If not set, `build.rs` looks for them at `engine_pjsip/build/out/` (default location).

---

## Troubleshooting Development Issues

| Problem | Solution |
|---------|----------|
| Hot-reload not working | Press `R` (restart). If still broken, exit and re-run `.\scripts\run_app.ps1` |
| DLL not found error | Run `.\.scripts\build_core_debug.ps1` manually, or check `app_flutter\build\windows\x64\runner\Debug\` |
| "Path too long" during Rust build | Script default maps to `X:\`. If issues persist, see [troubleshooting.md](troubleshooting.md) |
| Cargo build fails (no PJSIP) | PJSIP is required. Run `.\scripts\build_pjsip.ps1` first |
| Permission denied on DLL copy | Ensure PacketDial isn't running: `Get-Process PacketDial` → `Stop-Process -Name PacketDial` |

For more help, see [troubleshooting.md](troubleshooting.md).

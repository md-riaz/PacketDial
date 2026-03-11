# Rust Core

Current overview of `voip_core.dll`.

## What Rust Owns

The Rust layer sits between Flutter and PJSIP. It owns:

- exported FFI functions
- structured command dispatch
- runtime account and call maps
- native event serialization
- PJSIP account and call ID mappings
- audio device command handling
- global DND state
- recording event emission

Main source file:

- [`core_rust/src/lib.rs`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)

## PJSIP Boundary

Rust does not call PJSIP directly. Native SIP/media work goes through:

- [`core_rust/src/shim/pjsip_shim.c`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c)
- [`core_rust/src/shim/pjsip_shim.h`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.h)

This keeps PJSIP-specific code isolated from most of the Rust engine.

## Build Notes

The build script in [`core_rust/build.rs`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/build.rs):

- detects and links PJSIP
- compiles the shim
- emits the cfg needed for native-enabled builds

Typical commands:

```powershell
.\scripts\build_pjsip.ps1
.\scripts\build_core.ps1 -Configuration Debug
.\scripts\build_core.ps1 -Configuration Release
```

## API Model

The current engine API is mixed:

- direct C ABI exports for common functions
- `engine_send_command(...)` for many structured operations
- callback-based event delivery back to Flutter

The older "JSON-only command channel" description is stale. The active app uses both direct exports and structured command dispatch.

See:

- [`docs/FFI_API.md`](/C:/Users/vm_user/Downloads/PacketDial/docs/FFI_API.md)

## Current Native Behaviors Worth Knowing

- DND is enforced globally.
- Incoming calls are rejected with busy when another live call already exists.
- Recording is native WAV capture coordinated through the shim.
- Rust no longer owns the app's persisted call history.

## Troubleshooting

| Problem | Likely Fix |
|---------|------------|
| PJSIP link/build failure | Run `.\scripts\build_pjsip.ps1` first |
| `link.exe` missing | Install Visual Studio Build Tools with C++ workload |
| Flutter cannot load `voip_core.dll` | Rebuild core and confirm it is copied into the runner output |
| Event reaches Rust but not UI | Check event ID mapping in `engine.dart` and routing in `engine_channel.dart` |

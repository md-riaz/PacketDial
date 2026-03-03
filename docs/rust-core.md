# Rust Core (`voip_core.dll`) — Build & Architecture

This document describes the Rust FFI wrapper that mediates between Flutter and PJSIP.

---

## Overview

**voip_core.dll** is a Rust `cdylib` (C-compatible dynamic library) that:

1. **Wraps PJSIP** functionality via a thin C FFI shim (`src/shim/pjsip_shim.c`)
2. **Provides command/event channels** for JSON-based communication with Dart
3. **Falls back to stub mode** if PJSIP libs are unavailable (app remains functional)
4. **Compiles to both debug and release** modes for fast iteration and optimized releases

---

## Directory Structure

```
core_rust/
├── Cargo.toml               # Rust dependencies & package metadata
├── build.rs                 # Build script (detects PJSIP, links libs)
├── src/
│   ├── lib.rs              # Main DLL entry point, FFI exports
│   ├── shim/
│   │   └── pjsip_shim.c    # Thin C wrapper around PJSIP (conditionally compiled)
│   └── ...                 # Other Rust modules (state machines, events, etc)
└── target/
    └── x86_64-pc-windows-msvc/
        ├── debug/      # Fast iteration builds (~30-60 sec)
        └── release/    # Optimized, slower builds (~1-3 min)
```

---

## Build Configuration

### Cargo.toml

Key dependencies:

```toml
[dependencies]
serde = "1.0"
serde_json = "1.0"    # JSON command/event serialization
once_cell = "1.19"    # Lazy statics

[build-dependencies]
cc = "1.0"            # C compiler wrapper for linking PJSIP shim

[lib]
crate-type = ["cdylib"]  # Produce a dynamic library (DLL)
```

### build.rs (Build Script)

The `build.rs` script is the heart of the flexible build system:

#### 1. **Auto-detect PJSIP**
```rust
// Look for libs at standard location
let pjsip_lib_dir = env::var("PJSIP_LIB_DIR")
    .or_else(|_| .../* fallback paths */)
    .ok();

// Check if libs exist
if let Some(lib_dir) = &pjsip_lib_dir {
    println!("cargo:rustc-env=PJSIP_AVAILABLE=1");
}
```

#### 2. **Conditionally Compile C Shim**
If PJSIP is found:
```rust
let mut cc = cc::Build::new();
cc.file("src/shim/pjsip_shim.c")
  .include(&pjsip_include_dir)
  .compile("pjsip_shim");
```

#### 3. **Link Libraries**
```rust
// Link PJSIP static libs
for entry in fs::read_dir(lib_dir)? {
    if entry.path().extension() == Some("lib") {
        println!("cargo:rustc-link-lib=static={}", lib_name);
        println!("cargo:rustc-link-search=native={}", lib_dir);
    }
}

// Link Windows system libs (required by PJSIP)
println!("cargo:rustc-link-lib=ws2_32");    // Sockets
println!("cargo:rustc-link-lib=ole32");     // COM
println!("cargo:rustc-link-lib=uuid");      // UUIDs
println!("cargo:rustc-link-lib=winmm");     // Multimedia
println!("cargo:rustc-link-lib=Avrt");      // Audio/Video Rendering
```

---

## Build Modes

### Debug Mode (`cargo build`)

```powershell
$env:PJSIP_LIB_DIR = "engine_pjsip\build\out\lib"
$env:PJSIP_INCLUDE_DIR = "engine_pjsip\build\out\include"
cargo build --target x86_64-pc-windows-msvc

# Output: core_rust\target\x86_64-pc-windows-msvc\debug\voip_core.dll (~30-60 sec)
```

**Use for:**
- Active development with hot-reload
- Quick iteration when testing Rust changes
- Debugging with breakpoints

**Characteristics:**
- No optimization (fast compilation)
- Contains debug symbols
- Larger file size
- Slower runtime (but acceptable for development)

### Release Mode (`cargo build --release`)

```powershell
cargo build --release --target x86_64-pc-windows-msvc

# Output: core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll (~1-3 min)
```

**Use for:**
- Release/distribution artifacts
- Performance testing
- Final packaging

**Characteristics:**
- Full compiler optimizations
- No debug symbols (smaller)
- Slower compilation
- Optimized runtime performance

---

## Feature Flags

The `build.rs` script sets compile-time feature flags:

### `pjsip_available`

**Set if:** PJSIP static libs found at `engine_pjsip/build/out/lib/`

```rust
#[cfg(feature = "pjsip_available")]
mod pjsip {
    // Real SIP functionality
}

#[cfg(not(feature = "pjsip_available"))]
mod stub {
    // Stub SIP implementation
}
```

This allows:
- **Conditional compilation**: Only include PJSIP FFI if libs are present
- **Graceful fallback**: App runs with stub engine if PJSIP missing
- **Zero changes to Rust code**: Same source works with/without PJSIP

---

## FFI API

voip_core.dll exports these C-compatible functions:

### Command/Event Channel (Async JSON)

```c
// Send a JSON command, get back a string response
const char* engine_send_command(const char* json_cmd);

// Poll for the next pending event (non-blocking)
const char* engine_poll_event(void);

// Free a string returned by the above
void engine_free_string(const char* ptr);
```

### Direct C ABI (Structured Functions)

```c
// Initialize the engine
int engine_init(void);

// Register a SIP account
int engine_register(const char* user, const char* pass, const char* domain);

// Make an outgoing call
int engine_make_call(const char* phone_number);

// Hang up current call
int engine_hangup(void);

// Set event callback (receives structured events, not JSON)
void engine_set_event_callback(void (*cb)(const EngineEvent* ev));
```

See `docs/FFI_API.md` for complete signatures and examples.

---

## Linking Against voip_core.dll

### From Dart (Flutter)

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

final dylib = DynamicLibrary.open('voip_core.dll');
final engine_send_command = dylib
    .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('engine_send_command')
    .asFunction<Pointer<Utf8> Function(Pointer<Utf8>)>();
```

### From C/C++

```c
#include <windows.h>

typedef const char* (*engine_send_command_t)(const char*);

HMODULE dll = LoadLibraryA("voip_core.dll");
engine_send_command_t engine_send_command = (engine_send_command_t)
    GetProcAddress(dll, "engine_send_command");
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **"PJSIP libs not found"** | Run `.\scripts\build_pjsip.ps1` first, OR use stub mode (app still works) |
| **Cargo build fails with "link.exe not found"** | Install Visual Studio Build Tools with C++ Desktop workload |
| **"LNK1120: unresolved externals"** | Check that PJSIP libs are in `PJSIP_LIB_DIR` and `build.rs` finds them |
| **DLL not found at runtime** | Ensure `voip_core.dll` is copied to Flutter's build output (CMake or manual copy handles this) |
| **Hot-reload fails with DLL lock** | `.\scripts\run_app.ps1` kills running PacketDial process before copying DLL |

---

## Performance Considerations

1. **Debug vs Release**: Release mode is ~2-5x faster at runtime (use for benchmarks)
2. **Incremental Rebuilds**: Only changed Rust files recompile (leverages cargo's incremental feature)
3. **LTO (Link Time Optimization)**: Can be enabled in `Cargo.toml` for smaller, faster binaries (adds build time)

---

## See Also

- [PJSIP Build Guide](pjsip-build.md) — How to build PJSIP libs
- [FFI API Reference](FFI_API.md) — Complete function signatures
- [Developer Workflow](dev-workflow.md) — Hot-reload and debugging

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

Use the unified build script to compile the Rust core:

### Debug Mode (Fast)

```powershell
# Fast compilation (~30-60 sec), unoptimized, includes debug symbols
.\scripts\build_core.ps1 -Configuration Debug
```

**Use for:**
- Active development with hot-reload
- Quick iteration when testing Rust changes

### Release Mode (Optimized)

```powershell
# Slower compilation (~1-3 min), fully optimized, smaller binary
.\scripts\build_core.ps1 -Configuration Release
```

**Use for:**
- Release/distribution artifacts
- Performance testing

---

## FFI API

voip_core.dll exports a structured C-compatible API. The JSON-based command channel is no longer supported.

### Lifecycle

```c
int32_t engine_init(const char* user_agent);
int32_t engine_shutdown(void);
const char* engine_version(void);
```

### Account & Call Control

```c
int32_t engine_register(const char* account_id, const char* user, const char* pass, const char* domain);
int32_t engine_make_call(const char* account_id, const char* number);
int32_t engine_hangup(void);
```

### Events (Callback)

The engine delivers events via a native callback. Flutter registers this callback on startup.

```c
void engine_set_event_callback(void (*cb)(int event_id, const char* json_payload));
```

See `docs/FFI_API.md` for the complete list of functions, event IDs, and payload structures.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **"PJSIP libs not found"** | Run `.\scripts\build_pjsip.ps1` first, OR use stub mode (app still works) |
| **Cargo build fails with "link.exe not found"** | Install Visual Studio Build Tools with C++ Desktop workload |
| **DLL not found at runtime** | Ensure `voip_core.dll` is copied to Flutter's output folder (handled by `build_core.ps1`) |
| **Hot-reload fails with DLL lock** | `.\scripts\run_app.ps1` kills running PacketDial process before rebuilding |

---

## See Also

- [PJSIP Build Guide](pjsip-build.md) — How to build PJSIP libs
- [FFI API Reference](FFI_API.md) — Complete function signatures
- [Developer Workflow](dev-workflow.md) — Hot-reload and debugging

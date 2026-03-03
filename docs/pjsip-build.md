# PJSIP Build Guide (`engine_pjsip/`)

This document explains how PJSIP is built and integrated into PacketDial.

---

## Overview

**PJSIP** (portable JINGLE SIP) is a free, open-source SIP client library written in C. PacketDial uses it for:

- SIP registration and authentication
- Outgoing and incoming call setup
- RTP (media) streaming
- SIP transaction capture and diagnostics

---

## Directory Structure

```
engine_pjsip/
├── pjproject/                      # PJSIP 2.14.1 source (vendored in repo)
│   ├── pjlib/                      # Base library (strings, memory, etc)
│   ├── pjlib-util/                 # Utilities (JSON, XML, DNS, etc)
│   ├── pjmedia/                    # Media library (RTP, codecs, audio devices)
│   ├── pjnath/                     # NAT traversal (STUN, TURN)
│   ├── pjsip/                      # Core SIP stack
│   ├── pjsua/                      # Simplified SIP User Agent
│   ├── pjsua2/                     # Object-oriented SIP wrapper (we use this)
│   └── ...                         # Other modules
├── pjproject_config_site.h         # Windows x64-specific PJSIP config
├── build/
│   └── out/                        # Build output (created by scripts)
│       ├── lib/                    # Static .lib files for linking
│       └── include/                # Header files for C FFI
└── README.md                       # PJSIP integration notes
```

---

## How PJSIP is Vendored

PJSIP source is **committed directly to the repository** at `engine_pjsip/pjproject/` (~65 MB uncompressed).

Benefits:
- **Zero external downloads** needed during build (offline-friendly after initial clone)
- **Reproducible builds** — everyone builds the exact same version
- **Easy to patch** — can modify PJSIP config without submodule conflicts
- **CI/CD friendly** — no tool version mismatches

### Clone with Submodules

When cloning the repo:

```bash
git clone --recurse-submodules https://github.com/md-riaz/PacketDial
```

Or if already cloned:

```bash
git submodule update --init --recursive
```

---

## Build Configuration

### pjproject_config_site.h

This file sets compile-time options for PJSIP on Windows x64.

**Location:** `engine_pjsip/pjproject_config_site.h`

**Key Settings:**
```c
/* Audio backend (Windows Multimedia APIs) */
#define PJMEDIA_AUDIO_DEV_HAS_WMME 1
#define PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO 0

/* Enable floating-point support for audio DSP */
#define PJ_HAS_FLOATING_POINT 1

/* IPv6 support */
#define PJ_HAS_IPV6 1

/* TLS/SRTP security (for SIP over TLS, encrypted media) */
#define PJSIP_HAS_TLS_TRANSPORT 1
```

**When to Modify:**
- Enabling/disabling audio codecs
- Changing audio backend
- Adding TLS/OpenSSL support
- Adjusting memory/performance tuning

---

## Building PJSIP

### Prerequisites

- Visual Studio Build Tools 2022 (with C++ Desktop workload)
- MSBuild (included in Visual Studio)

### Build Script

```powershell
.\scripts\build_pjsip.ps1
```

**What it does:**

1. **Validates submodule** — Checks that `engine_pjsip/pjproject/` is initialized
2. **Locates MSBuild** — Finds Visual Studio installation via `vswhere.exe`
3. **Creates config_site.h** — If missing, generates default Windows x64 config
4. **Builds with MSBuild**:
   ```
   msbuild engine_pjsip\pjproject\pjproject-vs14.sln \
           /t:pjsua2_lib \
           /p:Configuration=Release \
           /p:Platform=x64 \
           /p:PlatformToolset=v143
   ```
5. **Collects outputs** — Copies `.lib` files and headers to `engine_pjsip/build/out/`
6. **Creates stamp file** — Records build timestamp for caching

### Parallel Builds

By default, uses all CPU cores:

```powershell
.\scripts\build_pjsip.ps1 -Jobs 4   # Or specify manually
```

### Build Output

**Location:** `engine_pjsip/build/out/`

```
out/
├── lib/                           # Static library files
│   ├── pjlib-x86_64-x64-vc14-Release.lib
│   ├── pjlib-util-x86_64-x64-vc14-Release.lib
│   ├── pjmedia-x86_64-x64-vc14-Release.lib
│   ├── pjsip-x86_64-x64-vc14-Release.lib
│   └── ... (more libs)
├── include/                       # Public header files
│   ├── pj/                        # Core headers (pj.h, pjlib, etc)
│   ├── pjsip/                     # SIP stack headers
│   ├── pjmedia/                   # Media headers
│   └── ... (more)
└── pjsip_build_stamp.txt          # Timestamp (for caching)
```

**Enviroment Variables Set:**

```powershell
$env:PJSIP_LIB_DIR     = "engine_pjsip/build/out/lib"
$env:PJSIP_INCLUDE_DIR = "engine_pjsip/build/out/include"
```

These are picked up by the Rust `build.rs` script for linking.

---

## Microsoft Visual Studio Solution

PJSIP includes pre-built Visual Studio solutions:

| Solution | Format | Toolset | Status |
|----------|--------|---------|--------|
| `pjproject-vs14.sln` | Modern (.vcxproj) | v143 (VS 2022) | ✅ Used by our build |
| `pjproject-vs8.sln` | Legacy (.vcproj) | v100 (VS 2010) | ❌ Outdated |

We use **vs14** because:
- Compatible with VS 2022 (v143 toolset)
- Modern MSBuild format (not legacy VCProj)
- Easier to patch and maintain

---

## Integration with Rust

### Rust Build Script (`core_rust/build.rs`)

After PJSIP is built, the Rust `build.rs` script:

1. **Auto-detects PJSIP libs**:
   ```rust
   let pjsip_lib_dir = env::var("PJSIP_LIB_DIR")
       .unwrap_or_else(|_| "engine_pjsip/build/out/lib".to_string());
   ```

2. **Links all .lib files**:
   ```rust
   for entry in fs::read_dir(lib_dir)? {
       if entry.path().extension() == Some("lib") {
           println!("cargo:rustc-link-lib=static={name}");
       }
   }
   ```

3. **Compiles C FFI shim** (`src/shim/pjsip_shim.c`):
   ```rust
   cc::Build::new()
       .file("src/shim/pjsip_shim.c")
       .include(&pjsip_include_dir)
       .compile("pjsip_shim");
   ```

4. **Sets cfg flag**: `pjsip_available` (enables PJSIP code paths)

PJSIP is **required** — the build will fail if libs are not found.
Run `scripts/build_pjsip.ps1` to build PJSIP before compiling the Rust core.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **"pjproject submodule not initialised"** | Run `git submodule update --init --recursive` |
| **"MSBuild not found"** | Install Visual Studio 2022 Build Tools from https://visualstudio.microsoft.com/downloads/ |
| **"No Release *.lib files found"** | Check MSBuild output above for errors; try deleting `engine_pjsip/pjproject/x64` and rebuilding |
| **"LNK1120: unresolved externals" (in Rust)** | Ensure all .lib files are in `PJSIP_LIB_DIR` and build.rs finds them |
| **"Windows SDK not found"** | Add "Desktop development with C++" workload when installing VS Build Tools |
| **Build takes >30 minutes** | PJSIP has many modules; first build always slower. Subsequent builds are cached. |

---

## Performance Notes

- **First build**: 5–20 minutes (depends on CPU, disk speed)
- **Incremental builds**: PJSIP is rarely changed; build outputs are cached by timestamp
- **Parallel jobs**: By default uses all CPU cores (`-Jobs $cpuCount`)

To force a clean rebuild:

```powershell
Remove-Item "engine_pjsip\pjproject\x64" -Recurse -Force
.\scripts\build_pjsip.ps1
```

---

## Common Modifications

### Disable a Feature

Edit `engine_pjsip/pjproject_config_site.h`:

```c
/* Disable a feature */
#define PJMEDIA_AUDIO_DEV_HAS_WMME 0

/* Then rebuild */
.\scripts\build_pjsip.ps1
```

### Change Audio Backend

```c
/* Disable WMME, enable other backend... */
#define PJMEDIA_AUDIO_DEV_HAS_WMME 0
#define PJMEDIA_AUDIO_DEV_HAS_WASAPI 1   // Windows Audio Session API
```

### Enable TLS/SRTP

```c
#define PJSIP_HAS_TLS_TRANSPORT 1
#define PJMEDIA_HAS_SRTP 1
```

Then rebuild PJSIP and Rust core.

---

## See Also

- [Rust Core Build Guide](rust-core.md) — How Rust links against PJSIP libs
- [Windows Setup Guide](windows_setup_guide.md) — Full build walkthrough
- [Official PJSIP Documentation](https://www.pjsip.org/) — Upstream project docs

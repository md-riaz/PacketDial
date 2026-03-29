# Build Notes (Windows)

## PJSIP
This scaffold expects PJSIP pjproject source code at:
- `engine_pjsip/pjproject/`

The script `scripts/build_pjsip.ps1` produces static libs under:
- `engine_pjsip/build/out/` (includes + libs)

Environment variables exported (for Rust build):
- `PJSIP_INCLUDE_DIR`
- `PJSIP_LIB_DIR`

## Rust core
Rust builds a `cdylib`:
- `core_rust/target/release/voip_core.dll`

The build script copies it into Flutter's runner folder for development:
- `app_flutter/windows/runner/`

## Flutter app
Uses Dart FFI to call:
- `engine_init()`
- `engine_shutdown()`
- `engine_version()`

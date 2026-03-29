# native/voip_core

This module documents the shared native telephony ABI used by PacketDial.
For this repository, it is a binary-only integration boundary for Windows and
Android. Rust is out of scope, and the app consumes prebuilt native libraries.

Purpose:
- define the public `engine_*` ABI used by Flutter through FFI
- keep the shared native headers and core sources in-repo for ABI reference
- document how vendored Windows and Android telephony binaries are packaged

Current contents:
- `include/voip_core.h`: shared exported ABI contract
- `src/core/engine_bridge.c`: current shared core implementation reference
- `src/shim/pjsip_shim.{c,h}`: shared shim/reference code kept with the ABI
- `sync_artifacts.ps1`: validates vendored runtime binaries and enforces the Android ABI policy
- `windows/build_windows.ps1`: validates the vendored Windows DLL
- `android/build_android.ps1`: validates the vendored Android `.so`

Supported workflow in this repo:
1. Keep the vendored Windows runtime at `native/vendor/windows/x64/voip_core.dll`.
2. Keep the vendored Android runtime at `apps/softphone_app/android/app/src/main/jniLibs/arm64-v8a/libvoip_core.so`.
3. Run `native/voip_core/sync_artifacts.ps1` to validate that the required binaries are present and that unsupported Android ABI folders are removed.

Current policy:
- Windows runtime is consumed from the vendored DLL.
- Android runtime is consumed from checked-in `jniLibs`.
- `arm64-v8a` is the only supported Android ABI in this repository.
- This repository treats the telephony core as a binary-only dependency.

If you receive a new native telephony binary drop:
1. Replace the vendored Windows DLL if it changed.
2. Replace the checked-in Android `arm64-v8a/libvoip_core.so` if it changed.
3. Run `native/voip_core/sync_artifacts.ps1`.
4. Rebuild the Flutter apps and verify the packaged artifacts.

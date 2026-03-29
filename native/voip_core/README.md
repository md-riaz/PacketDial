# native/voip_core

This module is the start of the non-Rust PacketDial telephony port.
It is intended to become the shared native telephony base for both Windows and
Android, with one exported ABI and one core implementation strategy.

Purpose:
- own the public `engine_*` ABI in-repo
- own the reusable PJSIP shim outside `reference/core_rust`
- provide shared Windows/Android native build entrypoints

Current contents:
- `include/voip_core.h`: shared exported ABI
- `src/core/engine_bridge.c`: initial engine wrapper that translates shim callbacks into PacketDial event payloads
- `src/shim/pjsip_shim.{c,h}`: extracted reusable PJSIP layer from the reference implementation
- `android/build_android.ps1`: Android build entrypoint for the port
- `windows/build_windows.ps1`: Windows build entrypoint for the same module
- `android/pjproject_config_site.h`: Android-specific PJSIP configuration used to stage mobile libs

Current status:
- The wrapper implements the direct telephony exports from the documented native API.
- `engine_send_command(...)` now covers the structured commands the Flutter app currently depends on: account profile upsert/delete, credential store/retrieve, diagnostics export, and ping.
- The Android and Windows scripts are entrypoints for converging both platforms onto this shared module.
- Android app packaging now ships shared-core builds from `apps/softphone_app/android/app/src/main/jniLibs/`.
- The vendored Windows `native/vendor/windows/x64/voip_core.dll` is now refreshed from this shared module's Windows build output.
- `CMakeLists.txt` now accepts a staged `VOIP_CORE_PJSIP_ROOT` with `include/` and `lib/` folders so both platforms can link against the same core sources.
- `sync_artifacts.ps1` is the canonical artifact refresh workflow for the current repo.

Next port steps:
1. Continue filling native command/event parity where Flutter still needs richer SIP/runtime truth.
2. Keep the vendored Windows DLL and Android `jniLibs` in sync from `native/voip_core`.
3. Expand Android ABI support only when packaging is deterministic for the extra ABI.

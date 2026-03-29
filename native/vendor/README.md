Vendored native runtime artifacts used by this workspace live here.

Current contents:
- `windows/x64/voip_core.dll`: vendored Windows runtime DLL consumed by the Flutter app packaging.

This project intentionally treats the native VoIP engine as a vendored binary
boundary. It does not require Rust, and the Flutter app only depends on the
stable FFI ABI exposed by the packaged native libraries.

Supported workflow:
- keep the Windows runtime DLL in `native/vendor/windows/x64/voip_core.dll`
- keep the Android runtime `.so` in `apps/softphone_app/android/app/src/main/jniLibs/arm64-v8a/libvoip_core.so`
- run `native/voip_core/sync_artifacts.ps1` to validate required binaries and enforce the Android ABI policy

This repository treats the telephony engine as a binary-only dependency. If the
telephony core changes, replace the vendored binaries with a new ABI-compatible
binary drop and rebuild the Flutter apps.

Vendored native runtime artifacts used by this workspace live here.

Current contents:
- `windows/x64/voip_core.dll`: vendored Windows runtime DLL consumed by the Flutter app packaging.

This project intentionally treats the native VoIP engine as a vendored binary
boundary. It does not require Rust, and the Flutter app only depends on the
stable FFI ABI exposed by the packaged native libraries.

The current workflow is:
- run `native/voip_core/sync_artifacts.ps1`
- copy the Windows `voip_core.dll` here for app packaging
- copy Android `libvoip_core.so` files into `apps/softphone_app/android/app/src/main/jniLibs/<abi>/`

If this DLL is updated, keep the ABI compatible with `packages/voip_bridge/lib/src/ffi/reference_engine_voip_bridge.dart` and the Windows packaging rules in `apps/softphone_app/windows/`.

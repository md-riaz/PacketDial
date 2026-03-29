# softphone_app

PacketDial Flutter application for Windows and Android.

## Native runtime

This app consumes prebuilt native telephony binaries through FFI:

- Windows: `native/vendor/windows/x64/voip_core.dll`
- Android: `android/app/src/main/jniLibs/arm64-v8a/libvoip_core.so`

The app does not depend on a `reference/` folder or a Rust toolchain.

## Validation

From the repo root:

- `powershell -ExecutionPolicy Bypass -File native/voip_core/sync_artifacts.ps1`
- `flutter analyze`
- `flutter build windows --debug`
- `flutter build apk --debug`

## Notes

- `arm64-v8a` is the only supported Android ABI in this repository.
- Replacing the telephony core means dropping in new ABI-compatible binaries and rebuilding the Flutter app.

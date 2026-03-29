# Android shared telephony port

This folder is the Android-specific build side of the shared `native/voip_core`
module.

Expected staged output per ABI:
- `native/voip_core/android/out/arm64-v8a/include`
- `native/voip_core/android/out/arm64-v8a/lib`
- `native/voip_core/android/out/armeabi-v7a/include`
- `native/voip_core/android/out/armeabi-v7a/lib`
- `native/voip_core/android/out/x86_64/include`
- `native/voip_core/android/out/x86_64/lib`

Workflow:
1. Run `build_pjsip_android.ps1` for an ABI to configure and build pjproject.
2. That stages headers/libs into `android/out/<abi>/`.
3. Point CMake at that staged root with `-DVOIP_CORE_PJSIP_ROOT=...`.
4. Build `libvoip_core.so` from the shared `native/voip_core` module.

This is the Android counterpart to `native/voip_core/windows/`.

Current bootstrap choices:
- disables `libwebrtc` and `libyuv` for the Android shared-core bring-up
- disables TLS until an Android OpenSSL/BoringSSL staging path is added
- keeps the focus on stable SIP registration, call control, RTP audio, and
  device routing first

This folder is reserved for optional manual Android native binary staging.

The active app packaging path is:
`apps/softphone_app/android/app/src/main/jniLibs/arm64-v8a/libvoip_core.so`

Current checked-in ABI:
- `arm64-v8a`

Current policy:
- `arm64-v8a` is the only supported Android ABI in app packaging.
- the app loads `libvoip_core.so` directly from checked-in `jniLibs`
- this repository does not rebuild Android telephony binaries from source

Keep this folder only as a workspace-owned place to stage alternative binary
drops before replacing the checked-in app `jniLibs` copy.

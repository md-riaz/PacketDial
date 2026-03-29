This folder is reserved for optional manual Android native binaries.

The active app packaging path is:
`apps/softphone_app/android/app/src/main/jniLibs/<abi>/libvoip_core.so`

Current checked-in ABIs:
- `arm64-v8a`

That keeps Android runtime loading simple because Flutter opens
`libvoip_core.so` directly through the platform dynamic loader.

Current policy:
- `arm64-v8a` is the only supported Android ABI in app packaging until a second ABI is verified to ship deterministically in the APK.

Keep the ABI subfolders with `.gitkeep` files here so teams still have a
workspace-owned place to stage alternative prebuilt Android artifacts while
updating the checked-in app `jniLibs` copy.

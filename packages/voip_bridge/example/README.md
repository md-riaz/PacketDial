# voip_bridge_example

Minimal example for loading the PacketDial `voip_bridge` package against the
current native runtime on the host platform.

## Expected native binaries

- Windows: `native/vendor/windows/x64/voip_core.dll`
- Android: app-packaged `libvoip_core.so`

The example is intended for local package development and ABI validation, not
as a standalone telephony product shell.

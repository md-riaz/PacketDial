# Issue: PJSIP Error 450002 - Device ID Out of Range on Call Make

## Status
**Fixed** — Implemented in v0.8.1

## Summary
When attempting to make an outgoing call, the engine fails with PJSIP error code `450002` indicating "A device ID has been used that is out of range for your system."

## Error Log
```
[EngineChannel] Event: EngineLog, Payload: {
  level: Error, 
  message: pd_call_make failed: acc_id=0 uri=sip:127@cpx.alphapbx.net:8090 status=450002 (A device ID has been used that is out of range for your system.), 
  ts: 1772694504
}

[EngineChannel] Event: EngineLog, Payload: {
  level: Error, 
  message: CallStart: pd_call_make failed for uri=sip:127@cpx.alphapbx.net:8090, 
  ts: 1772694504
}
```

## Implemented Fixes

The following fixes have been implemented to address this issue:

### Fix 1: Flutter-side Registration Check (dialer_screen.dart)
**Status**: ✅ Implemented

Added strict registration state validation before allowing call initiation:
- Account registration is now a **hard requirement** - calls are blocked if not registered
- Added `_showErrorDialog()` for user-friendly error messages
- Added `_showAudioDeviceWarning()` for audio device issues with override option
- Enhanced error handling in `_executeCall()` to display specific error messages based on return codes

**Files Modified**:
- `app_flutter/lib/screens/dialer_screen.dart`

### Fix 2: New EngineErrorCode.MediaNotReady (core_rust/src/lib.rs)
**Status**: ✅ Implemented

Added new error code `MediaNotReady = 7` to the `EngineErrorCode` enum for explicit media subsystem failures.

**Files Modified**:
- `core_rust/src/lib.rs`

### Fix 3: Media Readiness Check in PJSIP Shim (pjsip_shim.c)
**Status**: ✅ Implemented

Added `pd_check_media_ready()` function that:
- Enumerates audio devices before call attempt
- Validates presence of both capture (input) and playback (output) devices
- Returns specific error codes: `PJMEDIA_EAUD_NODEVICES`, `PJMEDIA_EAUD_NOINPUT`, `PJMEDIA_EAUD_NOOUTPUT`

**Files Modified**:
- `core_rust/src/shim/pjsip_shim.c`

### Fix 4: Audio Device Re-initialization on Error (pjsip_shim.c)
**Status**: ✅ Implemented

Added `pd_reinit_audio_devices()` function and retry logic in `pd_call_make()`:
- Detects error code 450002 (device ID out of range)
- Automatically re-enumerates audio devices
- Retries the call with refreshed device IDs
- Logs detailed diagnostic information

**Files Modified**:
- `core_rust/src/shim/pjsip_shim.c`

### Fix 5: Enhanced Error Handling in Rust Core (core_rust/src/lib.rs)
**Status**: ✅ Implemented

Updated `cmd_call_start()` to:
- Parse negated PJSIP status codes from `pd_call_make()`
- Return `EngineErrorCode::MediaNotReady` for device ID errors (450002)
- Return `EngineErrorCode::MediaNotReady` for PJMEDIA error range (430000-439999)
- Provide detailed error logging with actionable messages

**Files Modified**:
- `core_rust/src/lib.rs`

### Fix 6: Dart FFI Error Code Handling (dialer_screen.dart)
**Status**: ✅ Implemented

Updated `_executeCall()` to check return value and display appropriate error messages:
- Code 7 (MediaNotReady): "Audio devices are not ready. Please check your microphone and speaker settings."
- Code 6 (NotFound): "Account not found. Please verify your account is registered."
- Default: Generic error with code for debugging

**Files Modified**:
- `app_flutter/lib/screens/dialer_screen.dart`

## Technical Details

### Error Code Analysis
- **PJSIP Status Code**: `450002` (negated return value from `pd_call_make`)
- **Error Message**: "A device ID has been used that is out of range for your system"
- **Location**: `core_rust/src/shim/pjsip_shim.c` in `pd_call_make()`
- **PJSIP Function**: `pjsua_call_make_call()`

### Root Cause
The error occurs when PJSIP's media subsystem attempts to use an audio device ID that is invalid or out of range. This can happen when:
1. Audio devices haven't been enumerated yet
2. Device IDs have become stale due to hotplug/unplug events
3. No valid capture/playback devices are available
4. Account is not fully registered when call is attempted

### Call Flow (After Fix)
1. Flutter checks registration state - blocks if not registered
2. Flutter checks audio devices - warns if missing
3. Rust core calls `pd_call_make()`
4. PJSIP shim runs `pd_check_media_ready()` - validates devices exist
5. If error 450002 occurs, `pd_reinit_audio_devices()` is called
6. Call is retried with refreshed device IDs
7. Error is returned to Flutter with specific `MediaNotReady` code
8. User sees actionable error message

## Affected Components

| Component | File | Function |
|-----------|------|----------|
| PJSIP Shim | `core_rust/src/shim/pjsip_shim.c` | `pd_call_make()`, `pd_check_media_ready()`, `pd_reinit_audio_devices()` |
| Rust Core | `core_rust/src/lib.rs` | `cmd_call_start()`, `EngineErrorCode` |
| Flutter | `app_flutter/lib/screens/dialer_screen.dart` | `_call()`, `_executeCall()`, `_showErrorDialog()`, `_showAudioDeviceWarning()` |

## Reproduction Steps (For Testing Fix)

1. Launch PacketDial application
2. Configure SIP account (server: `cpx.alphapbx.net:8090`)
3. Wait for account registration (verify `RegistrationStateChanged` to `Registered`)
4. **Test case A**: Disable audio devices in Windows Sound settings
5. Attempt to dial - should see user-friendly error message
6. **Test case B**: Re-enable audio devices
7. Retry call - should succeed after automatic device re-enumeration

## Testing Plan

### Unit Tests
- [ ] Mock PJSIP return value 450002, verify `MediaNotReady` error returned
- [ ] Test `pd_check_media_ready()` with no devices
- [ ] Test `pd_check_media_ready()` with input-only devices
- [ ] Test `pd_check_media_ready()` with output-only devices
- [ ] Test `pd_reinit_audio_devices()` retry logic

### Integration Tests
- [ ] Start app with no audio devices, verify graceful failure
- [ ] Unplug audio device during call setup, verify retry succeeds
- [ ] Call with unregistered account, verify blocked with message

### Manual Tests
- [ ] Disable audio devices in Windows Sound settings
- [ ] Launch app, attempt call - verify error message
- [ ] Re-enable devices, retry call - verify success
- [ ] Normal calls with valid devices still work

### Regression Tests
- [ ] Normal outgoing calls work
- [ ] Incoming calls work
- [ ] Audio device switching works
- [ ] Account registration flow unchanged

## Related Documentation

- [FFI API](../FFI_API.md) — `CallStart` command specification
- [Rust Core](../rust-core.md) — Media subsystem initialization
- [Troubleshooting](../troubleshooting.md) — Audio device issues
- [PJSIP Build](../pjsip-build.md) — WASAPI configuration

## References

- PJSIP Documentation: https://www.pjsip.org/
- PJSIP Error Codes: `pjmedia` error codes start at 450000
- Windows WASAPI: https://docs.microsoft.com/en-us/windows/win32/coreaudio/wasapi

## Timeline

| Date | Event |
|------|-------|
| 2026-03-05 | Issue reported with error logs |
| 2026-03-05 | Fixes implemented: registration check, media readiness validation, retry logic, error handling |

## Labels
- `bug`
- `pjsip`
- `audio-device`
- `call-failure`
- `fixed`

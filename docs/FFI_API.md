# Rust <-> Flutter FFI API

This document describes the active native API surface used by PacketDial today.

## API Shape

PacketDial currently uses both:

- direct exported C ABI functions for common engine operations
- `engine_send_command(...)` for higher-level structured commands

Events are delivered through a single native callback as `(event_id, json_payload)`.

## Core Exports

```c
int32_t engine_init(const char* user_agent);
int32_t engine_shutdown(void);
const char* engine_version(void);
void engine_set_event_callback(void (*cb)(int event_id, const char* json_payload));
int32_t engine_send_command(const char* cmd_type, const char* json_payload);
```

## Direct Call/Audio Exports

```c
int32_t engine_register(const char* account_id, const char* user, const char* pass, const char* domain);
int32_t engine_unregister(const char* account_id);
int32_t engine_make_call(const char* account_id, const char* number);
int32_t engine_answer_call(void);
int32_t engine_hangup(void);
int32_t engine_set_mute(int32_t muted);
int32_t engine_set_hold(int32_t on_hold);
int32_t engine_send_dtmf(const char* digits);
int32_t engine_play_dtmf(const char* digits);
int32_t engine_start_recording(const char* file_path);
int32_t engine_stop_recording(void);
int32_t engine_is_recording(void);
int32_t engine_transfer_call(int32_t call_id, const char* dest_uri);
int32_t engine_start_attended_xfer(int32_t call_id, const char* dest_uri);
int32_t engine_complete_xfer(int32_t call_a_id, int32_t call_b_id);
int32_t engine_merge_conference(int32_t call_a_id, int32_t call_b_id);
int32_t engine_list_audio_devices(void);
int32_t engine_set_audio_devices(int32_t input_id, int32_t output_id);
int32_t engine_set_log_level(const char* level);
int32_t engine_get_log_buffer(void);
```

## Structured Commands

The active `engine_send_command(...)` command set includes:

- `AccountUpsert`
- `AccountRegister`
- `AccountUnregister`
- `AccountSetSecurity`
- `CallStart`
- `CallAnswer`
- `CallHangup`
- `CallMute`
- `CallHold`
- `CallSendDtmf`
- `CallStartRecording`
- `CallStopRecording`
- `MediaStatsUpdate`
- `AccountSetForwarding`
- `AccountGetForwarding`
- `SetGlobalDnd`
- `AccountSetLookupUrl`
- `AccountGetLookupUrl`
- `AccountSetCodecPriority`
- `AccountGetCodecPriority`
- `AccountSetCodec`
- `AccountSetAutoAnswer`
- `AccountGetAutoAnswer`
- `AccountSetDtmfMethod`
- `AccountGetDtmfMethod`
- `AccountDeleteProfile`
- `SetGlobalCodecPriority`
- `GetGlobalCodecPriority`
- `SetGlobalDtmfMethod`
- `GetGlobalDtmfMethod`
- `SetGlobalAutoAnswer`
- `GetGlobalAutoAnswer`
- `BlfSubscribe`
- `BlfUnsubscribe`
- `AudioListDevices`
- `AudioSetDevices`
- `SipCaptureMessage`
- `DiagExportBundle`
- `CredStore`
- `CredRetrieve`
- `EnginePing`
- `SetLogLevel`
- `GetLogBuffer`

## Active Event IDs

Current event ID map used by Flutter:

| ID | Name |
|----|------|
| 1 | `EngineReady` |
| 2 | `RegistrationStateChanged` |
| 3 | `CallStateChanged` |
| 4 | `MediaStatsUpdated` |
| 5 | `AudioDeviceList` |
| 6 | `AudioDevicesSet` |
| 7 | `CallHistoryResult` |
| 8 | `SipMessageCaptured` |
| 9 | `DiagBundleReady` |
| 10 | `AccountSecurityUpdated` |
| 11 | `CredStored` |
| 12 | `CredRetrieved` |
| 13 | `EnginePong` |
| 14 | `LogLevelSet` |
| 15 | `LogBufferResult` |
| 16 | `EngineLog` |
| 17 | `CallTransferInitiated` |
| 18 | `CallTransferStatus` |
| 19 | `CallTransferCompleted` |
| 20 | `ConferenceMerged` |
| 21 | `ForwardingUpdated` |
| 22 | `ForwardingResult` |
| 23 | `GlobalDndUpdated` |
| 24 | `BlfSubscribed` |
| 25 | `BlfUnsubscribed` |
| 26 | `BlfStatus` |
| 27 | `LookupUrlUpdated` |
| 28 | `LookupUrlResult` |
| 29 | `CodecPriorityUpdated` |
| 30 | `CodecPriorityResult` |
| 31 | `CodecUpdated` |
| 32 | `AutoAnswerUpdated` |
| 33 | `AutoAnswerResult` |
| 34 | `DtmfMethodUpdated` |
| 35 | `DtmfMethodResult` |
| 38 | `AccountProfileDeleted` |
| 39 | `GlobalCodecPriorityUpdated` |
| 40 | `GlobalCodecPriorityResult` |
| 41 | `GlobalDtmfMethodUpdated` |
| 42 | `GlobalDtmfMethodResult` |
| 43 | `GlobalAutoAnswerUpdated` |
| 44 | `GlobalAutoAnswerResult` |
| 45 | `RecordingStarted` |
| 46 | `RecordingStopped` |
| 47 | `RecordingSaved` |
| 48 | `RecordingError` |

Notes:

- IDs 36-37 are intentionally unused after account config import/export removal.
- Flutter-owned call history means older Rust history docs are stale, even though `CallHistoryResult` remains reserved in the event map.

## Event Payload Style

Rust emits callback payloads in the form:

```json
{
  "type": "CallStateChanged",
  "payload": {
    "call_id": 1,
    "state": "Ringing"
  }
}
```

## Where to Update This

When changing the API, update all of:

- [`core_rust/src/lib.rs`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)
- [`app_flutter/lib/ffi/engine.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/ffi/engine.dart)
- [`app_flutter/lib/core/engine_channel.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart)

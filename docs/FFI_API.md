# Rust <-> Flutter FFI API (v1)

PacketDial uses a structured C ABI for communication between Dart and Rust.

## C ABI Core

All functions use `extern "C"` and stable primitive types.

```c
// Initialize the engine. returns 0 on success.
int32_t engine_init(const char* user_agent);

// Shutdown the engine. returns 0 on success.
int32_t engine_shutdown(void);

// Returns pointer to a static null-terminated UTF-8 version string.
const char* engine_version(void);

// Set a callback for events.
//   cb: function pointer with signature (int event_id, const char* json_payload)
void engine_set_event_callback(void (*cb)(int event_id, const char* json_payload));
```

## Structured API Commands

These functions provide the primary interface for controlling the VoIP engine.

```c
// Register a SIP account.
// Returns 0 on success, non-zero on error.
int32_t engine_register(const char* account_id, const char* user, const char* pass, const char* domain);

// Unregister a SIP account.
int32_t engine_unregister(const char* account_id);

// Make an outgoing call.
int32_t engine_make_call(const char* account_id, const char* number);

// Answer an incoming call.
int32_t engine_answer_call(void);

// Hang up the current active call.
int32_t engine_hangup(void);

// Toggle mute (1=muted, 0=unmuted).
int32_t engine_set_mute(int32_t muted);

// Toggle hold (1=on_hold, 0=resumed).
int32_t engine_set_hold(int32_t on_hold);

// Send DTMF digits.
int32_t engine_send_dtmf(const char* digits);

// Request audio device list (triggers AudioDeviceList event).
int32_t engine_list_audio_devices(void);

// Set active audio devices.
int32_t engine_set_audio_devices(int32_t input_id, int32_t output_id);

// Request call history (triggers CallHistoryResult event).
int32_t engine_query_call_history(void);

// Set engine log level ("Error", "Warn", "Info", "Debug").
int32_t engine_set_log_level(const char* level);

// Request all buffered logs (triggers LogBufferResult event).
int32_t engine_get_log_buffer(void);
```

## Events (via Callback)

Events are delivered to the registered callback. Each event has an `event_id` and a JSON string `payload`.

| ID | Name | Payload Key Fields |
|----|------|--------------------|
| 1 | `EngineReady` | _(empty)_ |
| 2 | `RegistrationStateChanged` | `account_id`, `state` (Unregistered/Registering/Registered/Failed), `reason` |
| 3 | `CallStateChanged` | `call_id`, `account_id`, `uri`, `direction`, `state`, `muted`, `on_hold` |
| 4 | `MediaStatsUpdated` | `call_id`, `jitter_ms`, `packet_loss_pct`, `codec`, `bitrate_kbps` |
| 5 | `AudioDeviceList` | `devices[]` (id/name/kind), `selected_input`, `selected_output` |
| 6 | `AudioDevicesSet` | `input_id`, `output_id` |
| 7 | `CallHistoryResult` | `entries[]` (call_id, account_id, uri, direction, started_at, ended_at, duration_secs, end_state) |
| 8 | `SipMessageCaptured` | `direction`, `raw` (masked) |
| 9 | `DiagBundleReady` | `anonymize`, `call_history_count`, `account_count` |
| 14| `LogLevelSet` | `level` |
| 15| `LogBufferResult` | `entries[]` (level, message, ts) |
| 16| `EngineLog` | `level`, `message`, `ts` |

---

## Remote API (IPC / JSON)

PacketDial exposes its functionality via a Windows Named Pipe, allowing non-FFI clients (like `pd.exe` or external scripts) to control the engine.

**Pipe Name:** `\\.\pipe\PacketDial.API`  
**Protocol:** Line-based JSON (each message must end with `\n`).

### Command Schema
Clients send a JSON object with `type` and `payload`.

| IPC Type | DLL Command Mapping |
|----------|----------------------|
| `CallStart` | `cmd_call_start` |
| `CallAnswer`| `cmd_call_answer`|
| `CallHangup`| `cmd_call_hangup`|
| `CallMute`  | `cmd_call_mute`  |
| `CallHold`  | `cmd_call_hold`  |
| `DiagBundle`| `cmd_diag_bundle`|

**Example Command:**
```json
{"type": "CallStart", "payload": {"uri": "sip:100@domain"}}
```

### Event Broadcasting
The IPC server broadcasts all engine events to **all connected pipe clients**. The JSON format matches the `payload` delivered to the C callback, but wrapped in a top-level `type` field.

**Example Event:**
```json
{"type": "CallStateChanged", "payload": {"call_id": 1, "state": "Confirmed"}}
```


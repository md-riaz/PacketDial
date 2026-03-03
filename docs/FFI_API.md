# Rust <-> Flutter FFI API (v0)

## C ABI
All functions use `extern "C"` and stable primitive types.

```c
// returns 0 on success, non-zero on failure
int32_t engine_init(void);

// returns 0 on success
int32_t engine_shutdown(void);

// returns pointer to a null-terminated UTF-8 string (static)
const char* engine_version(void);

// Send a JSON command to the engine.
// cmd_json must be a null-terminated UTF-8 string:
//   {"type": "CommandName", "payload": {...}}
// Returns 0 on success. Error codes:
//   1  AlreadyInitialized
//   2  NotInitialized
//   3  InvalidUtf8
//   4  InvalidJson
//   5  UnknownCommand
//   6  NotFound
// 100  InternalError
int32_t engine_send_command(const char* cmd_json);

// Poll for the next queued event from the engine.
// Returns a heap-allocated null-terminated UTF-8 JSON string, or NULL if the
// queue is empty.  Caller MUST free the result with engine_free_string.
// Event shape: {"type": "EventName", "payload": {...}}
char* engine_poll_event(void);

// Free a string previously returned by engine_poll_event.
void engine_free_string(char* ptr);
```

## Supported Commands

| Command              | Required payload fields                                                  |
|----------------------|--------------------------------------------------------------------------|
| `AccountUpsert`      | `id`, `display_name`, `server`, `username`, `password`, `transport` (udp/tcp), `stun_server`, `turn_server` |
| `AccountRegister`    | `id`                                                                     |
| `AccountUnregister`  | `id`                                                                     |
| `CallStart`          | `account_id`, `uri`                                                      |
| `CallAnswer`         | `call_id`                                                                |
| `CallHangup`         | `call_id`                                                                |
| `CallMute`           | `call_id`, `muted` (bool)                                                |
| `CallHold`           | `call_id`, `hold` (bool)                                                 |
| `MediaStatsUpdate`   | `call_id`, `jitter_ms`, `packet_loss_pct`, `codec`, `bitrate_kbps`      |
| `AudioListDevices`   | _(none)_                                                                 |
| `AudioSetDevices`    | `input_id`, `output_id`                                                  |
| `CallHistoryQuery`   | _(none)_                                                                 |
| `SipCaptureMessage`  | `direction` (send/recv), `raw` (SIP message text)                        |
| `DiagExportBundle`   | `anonymize` (bool, default true)                                         |
| `CredStore`          | `key`, `value`                                                           |
| `CredRetrieve`       | `key`                                                                    |
| `EnginePing`         | _(none)_                                                                 |
| `SetLogLevel`        | `level` (one of: `"Error"`, `"Warn"`, `"Info"`, `"Debug"`)              |
| `GetLogBuffer`       | _(none)_ — returns all buffered log entries as `LogBufferResult`         |

## Events Emitted

| Event                      | Key payload fields                                                  |
|----------------------------|---------------------------------------------------------------------|
| `EngineReady`              | _(empty)_                                                           |
| `RegistrationStateChanged` | `account_id`, `state` (Unregistered/Registering/Registered/Failed), `reason` |
| `CallStateChanged`         | `call_id`, `account_id`, `uri`, `direction`, `state`, `muted`, `on_hold` |
| `MediaStatsUpdated`        | `call_id`, `jitter_ms`, `packet_loss_pct`, `codec`, `bitrate_kbps` |
| `AudioDeviceList`          | `devices[]` (id/name/kind), `selected_input`, `selected_output`    |
| `AudioDevicesSet`          | `input_id`, `output_id`                                             |
| `CallHistoryResult`        | `entries[]` (call_id, account_id, uri, direction, started_at, ended_at, duration_secs, end_state) |
| `SipMessageCaptured`       | `direction`, `raw` (masked)                                         |
| `DiagBundleReady`          | `anonymize`, `call_history_count`, `account_count`, `note`          |
| `CredStored`               | `key`                                                               |
| `CredRetrieved`            | `key`, `value`                                                      |
| `EnginePong`               | _(empty)_                                                           |
| `LogLevelSet`              | `level`                                                             |
| `EngineLog`                | `level` (Error/Warn/Info/Debug), `message`, `ts` (Unix seconds)     |
| `LogBufferResult`          | `entries[]` (level, message, ts) — response to `GetLogBuffer`       |


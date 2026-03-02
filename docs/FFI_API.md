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

| Command            | Required payload fields                                                  |
|--------------------|--------------------------------------------------------------------------|
| `AccountUpsert`    | `id`, `display_name`, `server`, `username`, `password`                   |
| `AccountRegister`  | `id`                                                                     |
| `AccountUnregister`| `id`                                                                     |
| `CallStart`        | `account_id`, `uri`                                                      |
| `CallAnswer`       | `call_id`                                                                |
| `CallHangup`       | `call_id`                                                                |
| `CallMute`         | `call_id`, `muted` (bool)                                                |
| `CallHold`         | `call_id`, `hold` (bool)                                                 |
| `DiagExportBundle` | `anonymize` (bool, default true)                                         |

## Events Emitted

| Event                      | Key payload fields                                                  |
|----------------------------|---------------------------------------------------------------------|
| `EngineReady`              | _(empty)_                                                           |
| `RegistrationStateChanged` | `account_id`, `state` (Unregistered/Registering/Registered/Failed), `reason` |
| `CallStateChanged`         | `call_id`, `account_id`, `uri`, `direction`, `state`, `muted`, `on_hold` |
| `DiagBundleReady`          | `anonymize`, `note`                                                 |


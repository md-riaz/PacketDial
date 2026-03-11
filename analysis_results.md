# PacketDial - Logical & Flow Inefficiency Analysis

Analysis across Flutter (`app_flutter`), Rust (`core_rust`), and C (`core_rust/src/shim/pjsip_shim.c`).

This file has been updated on March 11, 2026 to reflect fixes already present in the working tree.

Status legend:
- `Fixed`: implemented in code
- `Partially Fixed`: the original problem was reduced, but the underlying concern is not fully eliminated
- `Open`: still present

---

## Critical Inefficiencies

### 1. O(n) Linear Scans on `Vec` Instead of `HashMap` Lookups - Rust

**Status:** `Fixed`

**Files:** `core_rust/src/lib.rs`

`ACCOUNTS` and `CALLS` now use:

```rust
static ACCOUNTS: Lazy<Mutex<HashMap<String, Account>>> = Lazy::new(|| Mutex::new(HashMap::new()));
static CALLS: Lazy<Mutex<HashMap<u32, Call>>> = Lazy::new(|| Mutex::new(HashMap::new()));
```

The main `Vec`-based `.iter().find(...)` lookup pattern was replaced with `get()` / `get_mut()` or `values()` where appropriate.

---

### 2. Redundant Audio Device Enumeration - C

**Status:** `Fixed`

**Files:** `core_rust/src/shim/pjsip_shim.c`, `core_rust/src/shim/pjsip_shim.h`, `core_rust/src/lib.rs`

The old `pd_aud_dev_count()` + repeated `pd_aud_dev_info()` pattern was replaced with batch enumeration via `pd_aud_dev_list(...)`, and Rust now consumes that batch API in one pass.

Remaining note:
- Other audio-related code paths may still enumerate devices for validation/logging, but the specific N+1 device-listing path called out here is removed.

---

### 3. Hand-Rolled JSON Serialization Prone to Injection - Rust

**Status:** `Fixed`

**Files:** `core_rust/src/lib.rs`

The event emitters that were previously building JSON with `format!()` were migrated to structured `serde_json::json!(...)` payloads passed through `push_event(...)`.

This removes the original broken-string / unescaped-interpolation risk for the analyzed event paths.

---

### 4. Duplicate Call History - Flutter + Rust

**Status:** `Fixed`

**Files:** `app_flutter/lib/core/engine_channel.dart`, `app_flutter/lib/ffi/engine.dart`, `app_flutter/lib/screens/history_screen.dart`, `core_rust/src/lib.rs`

Rust-side `CALL_HISTORY` and the `queryCallHistory` round-trip were removed from the active flow. Flutter JSON storage is now the effective source of truth for call history.

Compatibility note:
- A reserved `callHistoryResult` event ID constant still exists in Flutter for test/ABI stability, but the runtime handling and Rust command path were removed.

---

## Moderate Inefficiencies

### 5. `removeAt(0)` on Dart List - O(n) Shift

**Status:** `Fixed`

**Files:** `app_flutter/lib/core/engine_channel.dart`

The event log, log buffer, and SIP message buffer now use `Queue` with `addLast()` / `removeFirst()` instead of `List.removeAt(0)`.

---

### 6. Multiple Mutex Locks Per Event - Rust

**Status:** `Partially Fixed`

**Files:** `core_rust/src/lib.rs`

The callback path is lighter than before because Rust call history was removed, so the extra `CALL_HISTORY` lock is gone.

However, `pjsip_on_call_state()` still takes multiple locks across the event path:
- `PJSIP_CALL_MAP`
- `CALLS`
- `MEDIA_STATS`
- `PJSIP_CALL_MAP` again on cleanup

This is better than before, but the broader contention concern is still valid.

---

### 7. `push_event()` Re-Parsed Its Own JSON - Rust

**Status:** `Fixed`

**Files:** `core_rust/src/lib.rs`

`push_event(...)` now accepts `(event_type, payload)` directly and no longer parses a JSON string just to extract and re-serialize the payload.

---

### 8. DND Is Global - Not Per-Account - C

**Status:** `Open`

**Files:** `core_rust/src/shim/pjsip_shim.c`

The DND path still behaves as a global toggle rather than a true per-account setting. This remains intentionally unfixed based on the implementation plan note that DND stays global.

This is still an architectural mismatch if the API surface implies per-account behavior.

---

### 9. Unnecessary `async` Functions Returning Synchronous Data - Flutter

**Status:** `Fixed`

**Files:** `app_flutter/lib/core/account_service.dart`, `app_flutter/lib/screens/accounts_screen.dart`, `app_flutter/lib/screens/dialer_screen.dart`, `app_flutter/lib/main.dart`

The synchronous account lookups were converted from `Future<...>` to plain sync getters, and the related providers were updated from `FutureProvider` to `Provider`.

---

### 10. Duplicate URI Normalization - Flutter + Rust

**Status:** `Fixed`

**Files:** `app_flutter/lib/screens/dialer_screen.dart`, `core_rust/src/lib.rs`

Flutter no longer pre-normalizes the dial target. Rust's `normalize_call_target_uri()` is now the active normalization layer.

---

## Minor Inefficiencies

### 11. Recording Stub Does Nothing - C

**Status:** `Open`

**Files:** `core_rust/src/shim/pjsip_shim.c`

The recording implementation still tracks recording state without actually writing media to disk. This remains a user-facing behavior risk.

---

### 12. `pd_acc_delete_profile` / `pd_acc_import_config` Are Stubs - C

**Status:** `Open`

**Files:** `core_rust/src/shim/pjsip_shim.c`

These functions still return stub failures and are not fully implemented in the C layer.

---

### 13. Missing `pd_ensure_thread()` Around Audio Device APIs - C

**Status:** `Fixed`

**Files:** `core_rust/src/shim/pjsip_shim.c`

The old `pd_aud_dev_info()` issue is no longer relevant because the device listing path now uses `pd_aud_dev_list(...)`, which calls `pd_ensure_thread()`. Related audio functions also now include explicit thread setup.

---

### 14. FFI Inside `ACCOUNTS` Lock - Rust

**Status:** `Fixed`

**Files:** `core_rust/src/lib.rs`

The getter paths called out in the analysis now fetch `pjsip_acc_id` under the lock and perform the FFI call after the lock is released.

This applies to:
- forwarding
- lookup URL
- codec priority
- auto-answer
- DTMF method

---

### 15. Double-Dispose of `TextEditingController` - Flutter

**Status:** `Fixed`

**Files:** `app_flutter/lib/screens/dialer_screen.dart`

The transfer dialog no longer disposes the controller in multiple close paths. Cleanup is centralized in the dialog completion path.

---

## Updated Summary Matrix

| # | Status | Layer | Issue |
|---|---|---|---|
| 1 | Fixed | Rust | O(1) map lookups replaced Vec scans |
| 2 | Fixed | C/Rust | Batch audio enumeration replaced N+1 device listing path |
| 3 | Fixed | Rust | Structured JSON replaced hand-built event JSON |
| 4 | Fixed | Flutter/Rust | Duplicate Rust call history flow removed |
| 5 | Fixed | Flutter | Queue-based ring buffers replaced `removeAt(0)` |
| 6 | Partially Fixed | Rust | Fewer locks than before, but event path still hops across several mutexes |
| 7 | Fixed | Rust | `push_event()` no longer re-parses its own JSON |
| 8 | Open | C | DND remains global |
| 9 | Fixed | Flutter | Sync getters no longer wrapped in unnecessary async/FutureProvider flow |
| 10 | Fixed | Flutter/Rust | URI normalization now lives in Rust |
| 11 | Open | C | Recording still stubbed |
| 12 | Open | C | Import/delete profile stubs remain |
| 13 | Fixed | C | Audio enumeration path now ensures thread registration |
| 14 | Fixed | Rust | FFI calls moved out of `ACCOUNTS` lock scope |
| 15 | Fixed | Flutter | Transfer dialog double-dispose issue removed |

---

## Remaining Highest-Value Open Items

1. Implement real recording in `pjsip_shim.c`, or make the UI/reporting explicitly state that recording is not functional yet.
2. Decide whether DND is intentionally global. If yes, rename the API/UX accordingly. If no, implement per-account storage and behavior.
3. Implement or remove the account import/delete profile shim stubs so Rust is not calling placeholder native functions.
4. If lock contention becomes noticeable, refactor the Rust callback/event path to reduce cross-mutex updates further.

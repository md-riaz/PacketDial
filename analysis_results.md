# PacketDial — Logical & Flow Inefficiency Analysis

Analysis across **Flutter** (`app_flutter`), **Rust** (`core_rust`), and **C** ([pjsip_shim.c](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c)).

---

## 🔴 Critical Inefficiencies

### 1. O(n) Linear Scans on `Vec` Instead of `HashMap` Lookups — Rust

**Files:** [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)

`ACCOUNTS`, `CALLS` are stored as `Vec`, yet nearly every function searches by `.uuid` or `.id` via `.iter().find(…)`. With `n` accounts/calls this is O(n) per lookup — and some functions do **multiple scans** within the same logic path.

```rust
// Example: cmd_call_answer scans CALLS twice with the same lock
let call_id = calls_guard.iter().find(|c| { ... }).map(|c| c.id);  // scan 1
calls_guard.iter().find(|c| c.id == call_id) // scan 2 — redundant
```

**Fix:** Replace `Vec<Account>` / `Vec<Call>` with `HashMap<String, Account>` / `HashMap<u32, Call>` for O(1) lookups.

---

### 2. Redundant Audio Device Enumeration — C

**File:** [pjsip_shim.c](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c)

[pd_aud_dev_count()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1280-1289) and [pd_aud_dev_info()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1290-1313) each independently call `pjsua_enum_aud_devs(infos, &count)` with a 64-element stack array. When Rust enumerates devices, it calls [pd_aud_dev_count()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1280-1289) (1 enumeration) then [pd_aud_dev_info()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1290-1313) **N times** (N enumerations). Total: **N+1 full enumerations** for what should be **1**.

```c
// pd_aud_dev_count:  enumerates all devices, returns count
// pd_aud_dev_info:   enumerates all devices AGAIN per call

unsigned pd_aud_dev_count(void) {
    pjmedia_aud_dev_info infos[64];  // stack alloc + full enum
    unsigned count = 64;
    pjsua_enum_aud_devs(infos, &count);
    return count;
}
```

Also, [pd_check_media_ready()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#816-889) + [pd_log_audio_state()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#136-180) + [pd_audio_device_exists()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#181-243) all repeat the same enumeration. A single [pd_call_make](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#934-997) triggers **4-5 redundant enumerations**.

**Fix:** Enumerate once and pass the result array, or cache device info.

---

### 3. Hand-Rolled JSON Serialization Prone to Injection — Rust

**File:** [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)

Many event push functions use `format!()` to construct JSON with **un-escaped string interpolation**:

```rust
// push_reg_state: account_name, display_name, reason are NOT escaped
push_event(format!(
    r#"{{"type":"RegistrationStateChanged","payload":{{"account_id":"{account_id}","account_name":"{account_name}",…}}}}"#
));
```

If `account_name` contains `"` or `}` or `\`, the JSON breaks. [push_call_state()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#1032-1078) already uses `serde_json::json!()` — but [push_reg_state()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#1006-1031), [push_media_stats()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#1079-1085), [cmd_call_history_query()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2080-2104), and ~15 other functions still use raw formatting.

**Fix:** Use `serde_json::json!()` + `.to_string()` everywhere — it's already a dependency.

---

### 4. Duplicate Call History — Flutter

**File:** [engine_channel.dart](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart#L477-L541)

When a call ends, [_handleEvent](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart#365-628) does **two** independent things:
1. Saves via `_accountService!.saveCallHistory(entry)` (writes JSON to disk)
2. Calls `_engine?.queryCallHistory()` (asks Rust for its in-memory history)

The Rust `CALL_HISTORY` and the Flutter `AccountService._history` are **completely separate, unsynchronized stores**. Every ended call gets recorded in both with different schemas and data formats. The Rust history is never actually displayed — it's only queried and then overwritten by the Flutter one.

**Fix:** Remove one of the two history stores. If Flutter's JSON file is the source of truth, remove the Rust `CALL_HISTORY` and the `queryCallHistory` round-trip entirely.

---

## 🟡 Moderate Inefficiencies

### 5. `removeAt(0)` on Dart List — O(n) Shift

**File:** [engine_channel.dart](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart#L232-L234)

```dart
eventLog.add(...);
if (eventLog.length > _kEventLogMax) {
    eventLog.removeAt(0);  // Shifts all elements — O(n)
}
```

Same pattern for `logBuffer` and `sipMessages`. These are ring buffers with caps of 200–500.

**Fix:** Use a proper ring buffer (e.g. `Queue` from `dart:collection`) or just `removeRange(0, overshoot)` in batches.

---

### 6. Multiple Mutex Locks Per Event — Rust

**File:** [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#L566-L608)

[pjsip_on_call_state()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#540-610) acquires **four separate mutex locks** for one event:
1. `PJSIP_CALL_MAP.lock()` — find our call ID
2. `CALLS.lock()` — update call state
3. `CALL_HISTORY.lock()` — if ended, push history
4. `MEDIA_STATS.lock()` — if ended, remove stats
5. `PJSIP_CALL_MAP.lock()` — again, to remove entry

This is logically correct but each lock adds contention on PJSIP callback threads.

---

### 7. [push_event()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#960-1000) Re-Parses Its Own JSON — Rust

**File:** [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#L962-L998)

[push_event()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#960-1000) takes a [String](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart#285-290) of JSON, immediately **re-parses** it with `serde_json::from_str()`, extracts the type and payload, re-serializes the payload with `serde_json::to_string()`, then invokes the callback.

```rust
fn push_event(json: String) {
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(&json) {  // parse
        if let Some(payload) = v.get("payload") {
            if let Ok(payload_json) = serde_json::to_string(payload) {  // re-serialize
                invoke_event_callback(event_id, &payload_json);
            }
        }
    }
    broadcast_ipc(json);  // also still uses original string
}
```

This means every event is serialized, parsed, re-serialized. Callers should pass structured data, not pre-formatted JSON.

**Fix:** Change [push_event](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#960-1000) to accept [(event_id: i32, payload: serde_json::Value)](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#254-264) directly.

---

### 8. DND Is Global — Not Per-Account — C

**File:** [pjsip_shim.c](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#L54)

[pd_acc_set_dnd()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1523-1537) accepts an `acc_id` parameter but sets a **single global** `g_dnd_enabled` flag:

```c
int pd_acc_set_dnd(int acc_id, int enabled) {
    g_dnd_enabled = enabled ? PJ_TRUE : PJ_FALSE;  // ignores acc_id!
}
```

Enabling DND on one account silently enables it for **all** accounts.

**Fix:** Use the per-account array pattern: `g_acc_dnd[MAX_ACCOUNTS]`.

---

### 9. Unnecessary `async` Functions Returning Synchronous Data — Flutter

**File:** [account_service.dart](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/account_service.dart#L223-L241)

```dart
Future<List<AccountSchema>> getAllAccounts() async {
    return _accounts;  // No await, no I/O — always synchronous
}
Future<AccountSchema?> getSelectedAccount() async {
    return _accounts.firstWhere((a) => a.isSelected);
}
Future<AccountSchema?> getAccountByUuid(String uuid) async {
    return _accounts.firstWhere((a) => a.uuid == uuid);
}
```

These are `async` functions wrapping purely synchronous lookups on `List`. The callers must `await` them unnecessarily (like in `selectedAccountProvider` which is a `FutureProvider` when it could be a simple `Provider`).

**Fix:** Make these synchronous or rename to [getAccountByUuidSync](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/account_service.dart#296-303) (which already exists as a duplicate).

---

### 10. Duplicate URI Normalization — Flutter + Rust

**Files:** [dialer_screen.dart](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/screens/dialer_screen.dart#L163-L186), [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#L1414-L1502)

URI normalization is duplicated in **two** layers:

1. **Flutter** [_executeCall()](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/screens/dialer_screen.dart#163-238) adds `sip:` prefix and `@server` domain
2. **Rust** [normalize_call_target_uri()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#1414-1437) does the exact same transforms

The Rust layer even logs "normalized target from X to Y" — but by that point the Flutter side already normalized it, so the Rust normalizer is a no-op.

**Fix:** Normalize in exactly one place (Rust is better since it has the domain hint from the account).

---

## 🟢 Minor Inefficiencies

### 11. Recording Stub Does Nothing — C

**File:** [pjsip_shim.c](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#L1628-L1682)

[pd_call_start_recording()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1628-1660) sets a flag and stores the path but explicitly states: *"This is a placeholder for future implementation. For now, we track recording state but don't actually write to file."* Yet Flutter's `RecordingService` calls this and reports success. Users may think recording is working when it silently does nothing.

---

### 12. [pd_acc_delete_profile](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1848-1855) / [pd_acc_import_config](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1839-1847) Are Stubs — C

**File:** [pjsip_shim.c](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#L1839-L1854)

Both return `-1` unconditionally:
```c
int pd_acc_import_config(...) { return -1; }
int pd_acc_delete_profile(...) { return -1; }
```
Yet Rust calls [pd_acc_delete_profile()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1848-1855) in [cmd_account_delete_profile](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#L2800) and ignores any failure.

---

### 13. [pd_aud_dev_count()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1280-1289) Doesn't Call [pd_ensure_thread()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#114-122) Properly

**File:** [pjsip_shim.c](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#L1280-L1288)

It calls [pd_ensure_thread()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#114-122) but then [pd_aud_dev_info()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1290-1313) (called right after for each device) does **not** call [pd_ensure_thread()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#114-122). If called on a different thread, it could crash PJSIP.

---

### 14. [cmd_account_get_forwarding](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2159-2202) Calls FFI While Holding `ACCOUNTS` Lock

**File:** [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#L2166-L2194)

This is the pattern the codebase previously identified as a **deadlock risk** (see conversation on "Fixing SIP Deadlocks"). The FFI call [pd_acc_get_forward()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1503-1522) happens inside the ACCOUNTS lock scope. Same issue in [cmd_account_get_auto_answer](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2593-2629), [cmd_account_get_dtmf_method](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2663-2695), [cmd_account_get_codec_priority](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2464-2509), [cmd_account_get_lookup_url](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2382-2422).

---

### 15. Double-Dispose of `TextEditingController` — Flutter

**File:** [dialer_screen.dart](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/screens/dialer_screen.dart#L533-L558)

In [_showTransferDialog](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/screens/dialer_screen.dart#439-560), the controller is disposed both in the `Cancel` button handler AND in the `.then()` callback. A properly closed dialog triggers both paths → double dispose → possible crash.

---

## Summary Priority Matrix

| # | Severity | Layer | Issue |
|---|----------|-------|-------|
| 1 | 🔴 | Rust | O(n) linear scans on Vec |
| 2 | 🔴 | C | Redundant audio enum (N+1 calls) |
| 3 | 🔴 | Rust | Un-escaped hand-rolled JSON |
| 4 | 🔴 | Flutter+Rust | Duplicate call history stores |
| 5 | 🟡 | Flutter | `removeAt(0)` on List — O(n) |
| 6 | 🟡 | Rust | Multiple locks per single event |
| 7 | 🟡 | Rust | [push_event](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#960-1000) re-parses own JSON |
| 8 | 🟡 | C | DND global instead of per-account |
| 9 | 🟡 | Flutter | Unnecessary async wrappers |
| 10 | 🟡 | Flutter+Rust | Duplicate URI normalization |
| 11 | 🟢 | C | Recording stub does nothing |
| 12 | 🟢 | C | Import/delete profile stubs called |
| 13 | 🟢 | C | Missing [pd_ensure_thread](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#114-122) |
| 14 | 🟢 | Rust | FFI inside ACCOUNTS lock (deadlock risk) |
| 15 | 🟢 | Flutter | Double dispose of controller |

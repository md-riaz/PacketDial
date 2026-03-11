# Fix Logical Inefficiencies Across Flutter, Rust, and C

Fixing the 14 actionable issues from the code analysis. DND stays global (intentional). Flutter is the source of truth for call history.

## User Review Required

> [!IMPORTANT]
> Phase 1 (Rust HashMap migration) touches most functions in [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs). The API behavior stays identical—only internal data structures change.

> [!WARNING]
> Phase 3a removes the Rust-side `CALL_HISTORY` store entirely. Flutter's JSON files become the sole call history. The `CallHistoryResult` event type and [cmd_call_history_query](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2080-2104) command will be removed.

## Proposed Changes

### Phase 1: Rust — Data Structures & JSON Safety

Fixes issues **#1**, **#3**, **#6**, **#7** from the analysis.

---

#### [MODIFY] [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)

**1a-1b: Replace `Vec` with `HashMap` for ACCOUNTS and CALLS**

```diff
-static ACCOUNTS: Lazy<Mutex<Vec<Account>>> = Lazy::new(|| Mutex::new(Vec::new()));
-static CALLS: Lazy<Mutex<Vec<Call>>> = Lazy::new(|| Mutex::new(Vec::new()));
+static ACCOUNTS: Lazy<Mutex<HashMap<String, Account>>> = Lazy::new(|| Mutex::new(HashMap::new()));
+static CALLS: Lazy<Mutex<HashMap<u32, Call>>> = Lazy::new(|| Mutex::new(HashMap::new()));
```

**1c: Update all `.iter().find()` → `.get()` / `.get_mut()`**

Every function that does `accts.iter().find(|a| a.uuid == id)` becomes `accts.get(&id)`. Every function that does `calls.iter_mut().find(|c| c.id == call_id)` becomes `calls.get_mut(&call_id)`. This is ~30 sites.

Example:
```diff
 // cmd_account_upsert
-if let Some(existing) = accts.iter_mut().find(|a| a.uuid == uuid) {
+if let Some(existing) = accts.get_mut(&uuid) {
     existing.account_name = ...
 } else {
-    accts.push(acct);
+    accts.insert(uuid.clone(), acct);
 }
```

**1d: Replace hand-rolled JSON with `serde_json::json!()` in ~15 push functions**

Affected functions: [push_reg_state](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#1006-1031), [push_media_stats](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#1079-1085), [cmd_call_history_query](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2080-2104), [cmd_account_set_forwarding](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2109-2158), [cmd_account_get_forwarding](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2159-2202), [cmd_account_set_dnd](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2203-2245), [cmd_blf_subscribe](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2246-2303), [cmd_blf_unsubscribe](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2304-2338), [cmd_account_set_lookup_url](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2339-2381), [cmd_account_get_lookup_url](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2382-2422), [cmd_account_set_codec_priority](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2427-2463), [cmd_account_get_codec_priority](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2464-2509), [cmd_account_set_codec](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2510-2553), [cmd_account_set_auto_answer](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2554-2592), [cmd_account_get_auto_answer](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2593-2629), [cmd_account_set_dtmf_method](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2630-2662), [cmd_account_get_dtmf_method](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2663-2695), [cmd_audio_list_devices](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#1856-1983), [cmd_audio_set_devices](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#1984-2053), [cmd_sip_capture](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2945-2960), [cmd_diag_export](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2961-2970), and all global settings commands.

Example:
```diff
-push_event(format!(
-    r#"{{"type":"RegistrationStateChanged","payload":{{"account_id":"{account_id}","account_name":"{account_name}",…}}}}"#
-));
+push_event(serde_json::json!({
+    "type": "RegistrationStateChanged",
+    "payload": {
+        "account_id": account_id,
+        "account_name": account_name,
+        "display_name": display_name,
+        "server": server,
+        "username": username,
+        "state": state.variant_name(),
+        "reason": reason,
+    }
+}).to_string());
```

**1e: Refactor [push_event](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#960-1000) to skip redundant parse/re-serialize**

Change [push_event](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#960-1000) from parsing JSON→extracting event_id→re-serializing payload, to directly accepting structured data:

```diff
-fn push_event(json: String) {
-    if let Ok(v) = serde_json::from_str::<serde_json::Value>(&json) {
-        // parse → lookup event type → re-serialize payload
-    }
-    broadcast_ipc(json);
-}
+fn push_event_structured(event_id: i32, payload: serde_json::Value) {
+    let payload_json = serde_json::to_string(&payload).unwrap_or_default();
+    invoke_event_callback(event_id, &payload_json);
+    let json = serde_json::json!({"type": event_id_to_str(event_id), "payload": payload}).to_string();
+    broadcast_ipc(json);
+}
+// Keep push_event(String) as a legacy wrapper for rare cases
```

---

### Phase 2: C — Redundant Audio Enumerations

Fixes issue **#2** and **#13**.

---

#### [MODIFY] [pjsip_shim.c](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c)

**2a: Add batch `pd_aud_dev_list()` function**

```c
// New: enumerate all devices in one call, return JSON-style packed data
int pd_aud_dev_list(char *json_buf, int json_len) {
    pd_ensure_thread();
    pjmedia_aud_dev_info infos[64];
    unsigned count = 64;
    if (pjsua_enum_aud_devs(infos, &count) != PJ_SUCCESS) return -1;
    // Write count + device entries into json_buf as JSON array
    // Single enumeration replaces N+1 calls
    ...
}
```

**2b: Add [pd_ensure_thread()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#114-122) to [pd_aud_dev_info()](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c#1290-1313)**

```diff
 int pd_aud_dev_info(unsigned idx, int *id_out, char *name_buf, int name_len, int *kind_out) {
+    pd_ensure_thread();
     pjmedia_aud_dev_info infos[64];
```

#### [MODIFY] [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)

**2c: Use batch API in [cmd_audio_list_devices](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#1856-1983)**

Replace the count + N info calls with a single `pd_aud_dev_list()` call.

---

### Phase 3: Flutter — Source of Truth & Cleanup

Fixes issues **#4**, **#5**, **#9**, **#10**, **#15**.

---

#### [MODIFY] [engine_channel.dart](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart)

**3a-3b: Remove Rust call history round-trip**

```diff
 // In CallStateChanged handler, when state == ended:
-_engine?.queryCallHistory();  // DELETE — Flutter JSON is source of truth
```

Remove the `CallHistoryResult` case from [_handleEvent](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart#365-628) and [_eventIdToType](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart#237-284) entirely.

**3e: Replace `removeAt(0)` ring buffers with `Queue`**

```diff
+import 'dart:collection';
 
-final List<String> eventLog = [];
-final List<LogEntry> logBuffer = [];
-final List<SipMessage> sipMessages = [];
+final Queue<String> eventLog = Queue();
+final Queue<LogEntry> logBuffer = Queue();
+final Queue<SipMessage> sipMessages = Queue();
```

```diff
-eventLog.add(jsonEncode({...}));
-if (eventLog.length > _kEventLogMax) {
-    eventLog.removeAt(0);  // O(n) shift
-}
+eventLog.addLast(jsonEncode({...}));
+while (eventLog.length > _kEventLogMax) {
+    eventLog.removeFirst();  // O(1)
+}
```

#### [MODIFY] [account_service.dart](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/account_service.dart)

**3c: Convert unnecessary async functions to sync**

```diff
-Future<List<AccountSchema>> getAllAccounts() async {
+List<AccountSchema> getAllAccounts() {
     return _accounts;
 }

-Future<AccountSchema?> getSelectedAccount() async {
+AccountSchema? getSelectedAccount() {
     try { return _accounts.firstWhere((a) => a.isSelected); }
     catch (_) { return null; }
 }

-Future<AccountSchema?> getAccountByUuid(String uuid) async {
+AccountSchema? getAccountByUuid(String uuid) {
     try { return _accounts.firstWhere((a) => a.uuid == uuid); }
     catch (_) { return null; }
 }
```

#### [MODIFY] [dialer_screen.dart](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/screens/dialer_screen.dart)

**3d: Remove duplicate URI normalization — Rust handles it**

```diff
 void _executeCall(Account activeAccount, String raw) {
-    String uri = originalTarget;
-    if (!uri.contains(':')) {
-        uri = server.isNotEmpty ? 'sip:$uri@$server' : 'sip:$uri';
-    } else if (uri.startsWith('sip:') || uri.startsWith('sips:')) {
-        if (!uri.contains('@') && server.isNotEmpty) {
-            uri = '$uri@$server';
-        }
-    } else {
-        uri = 'sip:$uri';
-    }
+    // URI normalization is handled by Rust's normalize_call_target_uri()
+    final uri = originalTarget;
```

Also update `selectedAccountProvider` from `FutureProvider` to `Provider` since [getSelectedAccount](file:///c:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/account_service.dart#227-234) is now sync.

**3f: Fix double-dispose in transfer dialog**

```diff
-}).then((_) {
-    transferCtrl.dispose();
-    transferFocusNode.dispose();
-});
+});
+// Controllers are disposed in Cancel/Transfer button handlers only
```

---

### Phase 4: Rust — Deadlock Safety

Fixes issue **#14**.

---

#### [MODIFY] [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)

Move FFI calls out of ACCOUNTS lock scope in 5 functions:

```diff
 fn cmd_account_get_forwarding(p: &Value) -> EngineErrorCode {
-    let (fwd_uri, fwd_flags) = {
-        let accounts = ACCOUNTS.lock().unwrap();
-        if let Some(acc) = accounts.iter().find(|a| a.uuid == account_id) {
-            if let Some(pj_acc_id) = acc.pjsip_acc_id {
-                // FFI call INSIDE lock — deadlock risk!
-                pd_acc_get_forward(pj_acc_id, ...)
+    let pj_acc_id = {
+        let accounts = ACCOUNTS.lock().unwrap();
+        accounts.get(&account_id).and_then(|a| a.pjsip_acc_id)
+    }; // lock released
+
+    let (fwd_uri, fwd_flags) = if let Some(pj_id) = pj_acc_id {
+        // FFI call OUTSIDE lock — safe
+        pd_acc_get_forward(pj_id, ...)
```

Same pattern for: [cmd_account_get_auto_answer](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2593-2629), [cmd_account_get_dtmf_method](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2663-2695), [cmd_account_get_codec_priority](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2464-2509), [cmd_account_get_lookup_url](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2382-2422).

---

### Phase 5: Rust CALL_HISTORY Removal

#### [MODIFY] [lib.rs](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)

Remove `CALL_HISTORY` static, [CallHistoryEntry](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#241-251) struct, [cmd_call_history_query](file:///c:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs#2080-2104), and all `CALL_HISTORY.lock()` calls.

---

## Verification Plan

### Automated Tests
1. `cd app_flutter && flutter test` — existing unit tests for models, event IDs
2. `cd core_rust && cargo build` — verify Rust compiles

### Manual Verification
1. Run [.\scripts\run_app.ps1](file:///c:/Users/vm_user/Downloads/PacketDial/scripts/run_app.ps1)
2. Register a SIP account — verify reg state events
3. Make a call — verify call state, media stats, DTMF
4. Check audio device list populates
5. End a call — verify call history saved in Flutter JSON (not Rust)
6. Check Diagnostics → Event Log renders properly with Queue

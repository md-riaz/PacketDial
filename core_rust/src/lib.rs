use once_cell::sync::Lazy;
use once_cell::sync::OnceCell;
use std::collections::VecDeque;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Mutex;

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

static INITIALIZED: AtomicBool = AtomicBool::new(false);
static VERSION: OnceCell<CString> = OnceCell::new();
static NEXT_CALL_ID: AtomicU32 = AtomicU32::new(1);

static EVENT_QUEUE: Lazy<Mutex<VecDeque<String>>> = Lazy::new(|| Mutex::new(VecDeque::new()));
static ACCOUNTS: Lazy<Mutex<Vec<Account>>> = Lazy::new(|| Mutex::new(Vec::new()));
static CALLS: Lazy<Mutex<Vec<Call>>> = Lazy::new(|| Mutex::new(Vec::new()));

// ---------------------------------------------------------------------------
// Error codes
// ---------------------------------------------------------------------------

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq)]
pub enum EngineErrorCode {
    Ok = 0,
    AlreadyInitialized = 1,
    NotInitialized = 2,
    InvalidUtf8 = 3,
    InvalidJson = 4,
    UnknownCommand = 5,
    NotFound = 6,
    InternalError = 100,
}

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
struct Account {
    id: String,
    display_name: String,
    server: String,
    username: String,
    password: String,
    reg_state: RegistrationState,
}

#[derive(Debug, Clone, PartialEq)]
enum RegistrationState {
    Unregistered,
    Registering,
    Registered,
    #[allow(dead_code)]
    Failed(String),
}

impl RegistrationState {
    fn variant_name(&self) -> &str {
        match self {
            Self::Unregistered => "Unregistered",
            Self::Registering => "Registering",
            Self::Registered => "Registered",
            Self::Failed(_) => "Failed",
        }
    }
}

#[derive(Debug, Clone)]
struct Call {
    id: u32,
    account_id: String,
    uri: String,
    direction: CallDirection,
    state: CallState,
    muted: bool,
    on_hold: bool,
}

#[derive(Debug, Clone)]
enum CallDirection {
    Outgoing,
    #[allow(dead_code)]
    Incoming,
}

impl CallDirection {
    fn variant_name(&self) -> &str {
        match self {
            Self::Outgoing => "Outgoing",
            Self::Incoming => "Incoming",
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
enum CallState {
    Ringing,
    InCall,
    OnHold,
    Ended,
}

impl CallState {
    fn variant_name(&self) -> &str {
        match self {
            Self::Ringing => "Ringing",
            Self::InCall => "InCall",
            Self::OnHold => "OnHold",
            Self::Ended => "Ended",
        }
    }
}

// ---------------------------------------------------------------------------
// Event helpers
// ---------------------------------------------------------------------------

fn push_event(json: String) {
    if let Ok(mut q) = EVENT_QUEUE.lock() {
        q.push_back(json);
    }
}

fn push_reg_state(account_id: &str, state: &RegistrationState) {
    let reason = match state {
        RegistrationState::Failed(r) => r.as_str(),
        _ => "",
    };
    push_event(format!(
        r#"{{"type":"RegistrationStateChanged","payload":{{"account_id":"{account_id}","state":"{}","reason":"{reason}"}}}}"#,
        state.variant_name()
    ));
}

fn push_call_state(call: &Call) {
    push_event(format!(
        r#"{{"type":"CallStateChanged","payload":{{"call_id":{},"account_id":"{}","uri":"{}","direction":"{}","state":"{}","muted":{},"on_hold":{}}}}}"#,
        call.id,
        call.account_id,
        call.uri,
        call.direction.variant_name(),
        call.state.variant_name(),
        call.muted,
        call.on_hold
    ));
}

// ---------------------------------------------------------------------------
// Command dispatch
// ---------------------------------------------------------------------------

fn dispatch_command(cmd_type: &str, payload: &serde_json::Value) -> EngineErrorCode {
    match cmd_type {
        "AccountUpsert" => cmd_account_upsert(payload),
        "AccountRegister" => cmd_account_register(payload),
        "AccountUnregister" => cmd_account_unregister(payload),
        "CallStart" => cmd_call_start(payload),
        "CallAnswer" => cmd_call_answer(payload),
        "CallHangup" => cmd_call_hangup(payload),
        "CallMute" => cmd_call_mute(payload),
        "CallHold" => cmd_call_hold(payload),
        "DiagExportBundle" => cmd_diag_export(payload),
        _ => EngineErrorCode::UnknownCommand,
    }
}

fn cmd_account_upsert(p: &serde_json::Value) -> EngineErrorCode {
    let id = match p["id"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let mut accts = ACCOUNTS.lock().unwrap();
    if let Some(existing) = accts.iter_mut().find(|a| a.id == id) {
        existing.display_name = p["display_name"].as_str().unwrap_or("").to_owned();
        existing.server = p["server"].as_str().unwrap_or("").to_owned();
        existing.username = p["username"].as_str().unwrap_or("").to_owned();
        existing.password = p["password"].as_str().unwrap_or("").to_owned();
    } else {
        let acct = Account {
            id: id.clone(),
            display_name: p["display_name"].as_str().unwrap_or("").to_owned(),
            server: p["server"].as_str().unwrap_or("").to_owned(),
            username: p["username"].as_str().unwrap_or("").to_owned(),
            password: p["password"].as_str().unwrap_or("").to_owned(),
            reg_state: RegistrationState::Unregistered,
        };
        accts.push(acct);
        drop(accts);
        push_reg_state(&id, &RegistrationState::Unregistered);
    }
    EngineErrorCode::Ok
}

fn cmd_account_register(p: &serde_json::Value) -> EngineErrorCode {
    let id = match p["id"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let mut accts = ACCOUNTS.lock().unwrap();
    match accts.iter_mut().find(|a| a.id == id) {
        None => EngineErrorCode::NotFound,
        Some(acct) => {
            acct.reg_state = RegistrationState::Registering;
            drop(accts);
            push_reg_state(&id, &RegistrationState::Registering);
            // TODO: trigger real PJSIP registration here.
            // Stub: transition immediately to Registered.
            let mut accts2 = ACCOUNTS.lock().unwrap();
            if let Some(a) = accts2.iter_mut().find(|a| a.id == id) {
                a.reg_state = RegistrationState::Registered;
            }
            drop(accts2);
            push_reg_state(&id, &RegistrationState::Registered);
            EngineErrorCode::Ok
        }
    }
}

fn cmd_account_unregister(p: &serde_json::Value) -> EngineErrorCode {
    let id = match p["id"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let mut accts = ACCOUNTS.lock().unwrap();
    match accts.iter_mut().find(|a| a.id == id) {
        None => EngineErrorCode::NotFound,
        Some(acct) => {
            acct.reg_state = RegistrationState::Unregistered;
            drop(accts);
            push_reg_state(&id, &RegistrationState::Unregistered);
            EngineErrorCode::Ok
        }
    }
}

fn cmd_call_start(p: &serde_json::Value) -> EngineErrorCode {
    let account_id = match p["account_id"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let uri = match p["uri"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let call_id = NEXT_CALL_ID.fetch_add(1, Ordering::SeqCst);
    let call = Call {
        id: call_id,
        account_id,
        uri,
        direction: CallDirection::Outgoing,
        state: CallState::Ringing,
        muted: false,
        on_hold: false,
    };
    push_call_state(&call);
    CALLS.lock().unwrap().push(call);
    // TODO: trigger real PJSIP call here.
    EngineErrorCode::Ok
}

fn cmd_call_answer(p: &serde_json::Value) -> EngineErrorCode {
    let call_id = match p["call_id"].as_u64() {
        Some(n) => n as u32,
        None => return EngineErrorCode::InvalidJson,
    };
    let mut calls_guard = CALLS.lock().unwrap();
    match calls_guard.iter_mut().find(|c| c.id == call_id) {
        None => EngineErrorCode::NotFound,
        Some(call) => {
            call.state = CallState::InCall;
            push_call_state(call);
            EngineErrorCode::Ok
        }
    }
}

fn cmd_call_hangup(p: &serde_json::Value) -> EngineErrorCode {
    let call_id = match p["call_id"].as_u64() {
        Some(n) => n as u32,
        None => return EngineErrorCode::InvalidJson,
    };
    let mut calls_guard = CALLS.lock().unwrap();
    match calls_guard.iter_mut().find(|c| c.id == call_id) {
        None => EngineErrorCode::NotFound,
        Some(call) => {
            call.state = CallState::Ended;
            push_call_state(call);
            EngineErrorCode::Ok
        }
    }
}

fn cmd_call_mute(p: &serde_json::Value) -> EngineErrorCode {
    let call_id = match p["call_id"].as_u64() {
        Some(n) => n as u32,
        None => return EngineErrorCode::InvalidJson,
    };
    let muted = p["muted"].as_bool().unwrap_or(true);
    let mut calls_guard = CALLS.lock().unwrap();
    match calls_guard.iter_mut().find(|c| c.id == call_id) {
        None => EngineErrorCode::NotFound,
        Some(call) => {
            call.muted = muted;
            push_call_state(call);
            EngineErrorCode::Ok
        }
    }
}

fn cmd_call_hold(p: &serde_json::Value) -> EngineErrorCode {
    let call_id = match p["call_id"].as_u64() {
        Some(n) => n as u32,
        None => return EngineErrorCode::InvalidJson,
    };
    let hold = p["hold"].as_bool().unwrap_or(true);
    let mut calls_guard = CALLS.lock().unwrap();
    match calls_guard.iter_mut().find(|c| c.id == call_id) {
        None => EngineErrorCode::NotFound,
        Some(call) => {
            call.on_hold = hold;
            call.state = if hold {
                CallState::OnHold
            } else {
                CallState::InCall
            };
            push_call_state(call);
            EngineErrorCode::Ok
        }
    }
}

fn cmd_diag_export(p: &serde_json::Value) -> EngineErrorCode {
    let anonymize = p["anonymize"].as_bool().unwrap_or(true);
    push_event(format!(
        r#"{{"type":"DiagBundleReady","payload":{{"anonymize":{anonymize},"note":"TODO: real export"}}}}"#
    ));
    EngineErrorCode::Ok
}

// ---------------------------------------------------------------------------
// Version string
// ---------------------------------------------------------------------------

fn version_cstr() -> &'static CString {
    VERSION.get_or_init(|| CString::new("voip_core 0.1.0").unwrap())
}

// ---------------------------------------------------------------------------
// C ABI — original surface
// ---------------------------------------------------------------------------

/// Initialize the engine.
/// In future milestones, this will initialize PJSIP and related subsystems.
#[no_mangle]
pub extern "C" fn engine_init() -> i32 {
    if INITIALIZED.swap(true, Ordering::SeqCst) {
        return EngineErrorCode::AlreadyInitialized as i32;
    }
    // TODO: initialize PJSIP here (pj_init, pjsua_create, etc.)
    push_event(r#"{"type":"EngineReady","payload":{}}"#.to_owned());
    EngineErrorCode::Ok as i32
}

/// Shutdown the engine.
#[no_mangle]
pub extern "C" fn engine_shutdown() -> i32 {
    if !INITIALIZED.swap(false, Ordering::SeqCst) {
        return EngineErrorCode::NotInitialized as i32;
    }
    // TODO: shutdown PJSIP here (pjsua_destroy, etc.)
    if let Ok(mut q) = EVENT_QUEUE.lock() {
        q.clear();
    }
    EngineErrorCode::Ok as i32
}

/// Returns a pointer to a static, null-terminated UTF-8 string.
/// The pointer remains valid for the lifetime of the process.
#[no_mangle]
pub extern "C" fn engine_version() -> *const c_char {
    version_cstr().as_ptr()
}

// ---------------------------------------------------------------------------
// C ABI — command / event channel
// ---------------------------------------------------------------------------

/// Send a JSON command to the engine.
///
/// `cmd_json` must be a null-terminated UTF-8 JSON string with the shape:
/// `{"type": "CommandName", "payload": {...}}`
///
/// Returns 0 (`EngineErrorCode::Ok`) on success, non-zero on failure.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn engine_send_command(cmd_json: *const c_char) -> i32 {
    if !INITIALIZED.load(Ordering::SeqCst) {
        return EngineErrorCode::NotInitialized as i32;
    }
    if cmd_json.is_null() {
        return EngineErrorCode::InvalidJson as i32;
    }
    let s = unsafe {
        match CStr::from_ptr(cmd_json).to_str() {
            Ok(s) => s,
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        }
    };
    let v: serde_json::Value = match serde_json::from_str(s) {
        Ok(v) => v,
        Err(_) => return EngineErrorCode::InvalidJson as i32,
    };
    let cmd_type = match v["type"].as_str() {
        Some(t) => t.to_owned(),
        None => return EngineErrorCode::InvalidJson as i32,
    };
    let empty = serde_json::Value::Object(Default::default());
    let payload = v.get("payload").unwrap_or(&empty);
    dispatch_command(&cmd_type, payload) as i32
}

/// Poll for the next queued event from the engine.
///
/// Returns a heap-allocated null-terminated UTF-8 JSON string, or null if the
/// queue is empty.  **The caller must free the returned pointer with
/// `engine_free_string`.**
#[no_mangle]
pub extern "C" fn engine_poll_event() -> *mut c_char {
    let json = {
        let mut q = EVENT_QUEUE.lock().unwrap();
        q.pop_front()
    };
    match json {
        None => std::ptr::null_mut(),
        Some(s) => match CString::new(s) {
            Ok(cs) => cs.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
    }
}

/// Free a string previously returned by `engine_poll_event`.
///
/// # Safety
/// `ptr` must be a non-null pointer previously returned by `engine_poll_event`
/// and must not be freed more than once.
#[no_mangle]
pub unsafe extern "C" fn engine_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    /// Serialise test execution so that global state does not leak between tests.
    static TEST_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

    fn reset() {
        INITIALIZED.store(false, Ordering::SeqCst);
        EVENT_QUEUE.lock().unwrap().clear();
        ACCOUNTS.lock().unwrap().clear();
        CALLS.lock().unwrap().clear();
    }

    fn drain_events() {
        loop {
            let ptr = engine_poll_event();
            if ptr.is_null() {
                break;
            }
            unsafe { engine_free_string(ptr) };
        }
    }

    fn send(cmd: &str) -> i32 {
        let cs = CString::new(cmd).unwrap();
        engine_send_command(cs.as_ptr())
    }

    fn next_event() -> String {
        let ptr = engine_poll_event();
        assert!(!ptr.is_null(), "expected an event but queue was empty");
        let s = unsafe { CStr::from_ptr(ptr).to_str().unwrap().to_owned() };
        unsafe { engine_free_string(ptr) };
        s
    }

    #[test]
    fn init_shutdown_ok() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        assert_eq!(engine_init(), EngineErrorCode::Ok as i32);
        assert_eq!(engine_shutdown(), EngineErrorCode::Ok as i32);
    }

    #[test]
    fn init_twice() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        assert_eq!(engine_init(), EngineErrorCode::Ok as i32);
        assert_eq!(engine_init(), EngineErrorCode::AlreadyInitialized as i32);
        assert_eq!(engine_shutdown(), EngineErrorCode::Ok as i32);
    }

    #[test]
    fn engine_ready_event() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        let ev = next_event();
        assert!(ev.contains("EngineReady"), "got: {ev}");
        engine_shutdown();
    }

    #[test]
    fn unknown_command_returns_error() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();
        assert_eq!(
            send(r#"{"type":"NoSuchCommand","payload":{}}"#),
            EngineErrorCode::UnknownCommand as i32
        );
        engine_shutdown();
    }

    #[test]
    fn invalid_json_returns_error() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();
        assert_eq!(
            send("not json"),
            EngineErrorCode::InvalidJson as i32
        );
        engine_shutdown();
    }

    #[test]
    fn account_register_flow() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        // Upsert account — emits Unregistered
        assert_eq!(
            send(r#"{"type":"AccountUpsert","payload":{"id":"acc1","display_name":"Test","server":"sip.example.com","username":"user","password":"pass"}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("Unregistered"), "got: {ev}");

        // Register — emits Registering then Registered
        assert_eq!(
            send(r#"{"type":"AccountRegister","payload":{"id":"acc1"}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("Registering"), "got: {ev}");
        let ev = next_event();
        assert!(ev.contains("Registered"), "got: {ev}");

        // Unregister
        assert_eq!(
            send(r#"{"type":"AccountUnregister","payload":{"id":"acc1"}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("Unregistered"), "got: {ev}");

        engine_shutdown();
    }

    #[test]
    fn account_not_found() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();
        assert_eq!(
            send(r#"{"type":"AccountRegister","payload":{"id":"missing"}}"#),
            EngineErrorCode::NotFound as i32
        );
        engine_shutdown();
    }

    #[test]
    fn call_flow() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        // Start call → Ringing
        assert_eq!(
            send(r#"{"type":"CallStart","payload":{"account_id":"acc1","uri":"sip:bob@example.com"}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("Ringing"), "got: {ev}");

        // Parse call_id from the event
        let v: serde_json::Value = serde_json::from_str(&ev).unwrap();
        let call_id = v["payload"]["call_id"].as_u64().unwrap();

        // Answer → InCall
        let cmd = format!(r#"{{"type":"CallAnswer","payload":{{"call_id":{call_id}}}}}"#);
        assert_eq!(send(&cmd), 0);
        let ev = next_event();
        assert!(ev.contains("InCall"), "got: {ev}");

        // Hold → OnHold
        let cmd = format!(r#"{{"type":"CallHold","payload":{{"call_id":{call_id},"hold":true}}}}"#);
        assert_eq!(send(&cmd), 0);
        let ev = next_event();
        assert!(ev.contains("OnHold"), "got: {ev}");

        // Mute
        let cmd = format!(r#"{{"type":"CallMute","payload":{{"call_id":{call_id},"muted":true}}}}"#);
        assert_eq!(send(&cmd), 0);
        let ev = next_event();
        assert!(ev.contains("OnHold"), "got: {ev}"); // state unchanged, muted=true

        // Hangup → Ended
        let cmd = format!(r#"{{"type":"CallHangup","payload":{{"call_id":{call_id}}}}}"#);
        assert_eq!(send(&cmd), 0);
        let ev = next_event();
        assert!(ev.contains("Ended"), "got: {ev}");

        engine_shutdown();
    }

    #[test]
    fn diag_export() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(
            send(r#"{"type":"DiagExportBundle","payload":{"anonymize":true}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("DiagBundleReady"), "got: {ev}");

        engine_shutdown();
    }
}

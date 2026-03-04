use interprocess::local_socket::{LocalSocketListener, LocalSocketStream};
use once_cell::sync::Lazy;
use once_cell::sync::OnceCell;
use std::collections::{HashMap, VecDeque};
use std::ffi::{CStr, CString};
use std::io::{BufRead, BufReader, Write};
use std::os::raw::c_char;
use std::panic::AssertUnwindSafe;
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU8, Ordering};
use std::sync::Mutex;
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH};

use crossbeam_channel::{unbounded, Sender};

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

static INITIALIZED: AtomicBool = AtomicBool::new(false);
static VERSION: OnceCell<CString> = OnceCell::new();
static NEXT_CALL_ID: AtomicU32 = AtomicU32::new(1);

static ACCOUNTS: Lazy<Mutex<Vec<Account>>> = Lazy::new(|| Mutex::new(Vec::new()));
static CALLS: Lazy<Mutex<Vec<Call>>> = Lazy::new(|| Mutex::new(Vec::new()));
static CALL_HISTORY: Lazy<Mutex<Vec<CallHistoryEntry>>> = Lazy::new(|| Mutex::new(Vec::new()));
static MEDIA_STATS: Lazy<Mutex<HashMap<u32, MediaStats>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static AUDIO_DEVICES: Lazy<Mutex<Vec<AudioDevice>>> = Lazy::new(|| {
    Mutex::new(vec![
        AudioDevice {
            id: 0,
            name: "Default Input".to_owned(),
            kind: AudioDeviceKind::Input,
        },
        AudioDevice {
            id: 1,
            name: "Default Output".to_owned(),
            kind: AudioDeviceKind::Output,
        },
    ])
});
static SELECTED_INPUT: AtomicU32 = AtomicU32::new(0);
static SELECTED_OUTPUT: AtomicU32 = AtomicU32::new(1);

/// In-memory credential store (key → value).
/// Persistence via Windows Credential Manager (wincred) is a future milestone.
static CRED_STORE: Lazy<Mutex<HashMap<String, String>>> = Lazy::new(|| Mutex::new(HashMap::new()));

/// Active log level filter. Messages with level ≤ this value are emitted and
/// buffered. Default: Info (2).  Levels: Error=0, Warn=1, Info=2, Debug=3.
static ACTIVE_LOG_LEVEL: AtomicU8 = AtomicU8::new(LogLevel::Info as u8);

/// Ring-buffer of recent log entries (capped at LOG_BUFFER_MAX).
static LOG_BUFFER: Lazy<Mutex<VecDeque<LogEntry>>> = Lazy::new(|| Mutex::new(VecDeque::new()));

const LOG_BUFFER_MAX: usize = 200;

// Maps pjsua_acc_id (i32) → our account id (String) — populated when an
// account is registered via pd_acc_add.
static PJSIP_ACC_MAP: Lazy<Mutex<HashMap<i32, String>>> = Lazy::new(|| Mutex::new(HashMap::new()));

// Maps pjsua_call_id (i32) → our internal call id (u32) — used to route
// PJSIP call-state callbacks back to the correct Call entry.
static PJSIP_CALL_MAP: Lazy<Mutex<HashMap<i32, u32>>> = Lazy::new(|| Mutex::new(HashMap::new()));

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
// Logging types
// ---------------------------------------------------------------------------

/// Severity level for engine log messages.
/// Stored as u8; lower value = higher severity.
#[repr(u8)]
#[derive(Debug, Copy, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum LogLevel {
    Error = 0,
    Warn = 1,
    Info = 2,
    Debug = 3,
}

impl LogLevel {
    fn as_str(self) -> &'static str {
        match self {
            Self::Error => "Error",
            Self::Warn => "Warn",
            Self::Info => "Info",
            Self::Debug => "Debug",
        }
    }

    fn from_str(s: &str) -> Option<Self> {
        match s {
            "Error" => Some(Self::Error),
            "Warn" => Some(Self::Warn),
            "Info" => Some(Self::Info),
            "Debug" => Some(Self::Debug),
            _ => None,
        }
    }

    fn from_u8(v: u8) -> Self {
        match v {
            0 => Self::Error,
            1 => Self::Warn,
            2 => Self::Info,
            _ => Self::Debug,
        }
    }
}

#[derive(Debug, Clone)]
struct LogEntry {
    level: LogLevel,
    message: String,
    ts: u64,
}

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
struct Account {
    uuid: String,
    account_name: String,
    display_name: String,
    server: String,
    sip_proxy: String,
    username: String,
    auth_username: String,
    domain: String,
    password: String,
    transport: String,
    stun_server: String,
    turn_server: String,
    /// Use TLS transport (SIP over TLS / SIPS).
    tls_enabled: bool,
    /// Require SRTP for media encryption.
    srtp_enabled: bool,
    reg_state: RegistrationState,
    /// PJSIP account id assigned by pjsua_acc_add (None before registration).
    pjsip_acc_id: Option<i32>,
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
    started_at: u64,
    /// Accumulated active duration (talk time) in seconds.
    accumulated_active_secs: u64,
    /// Timestamp of the last time the call was resumed/started.
    last_resumed_at: Option<u64>,
    /// PJSIP call id used for shim operations
    /// (None before the call is wired to PJSIP).
    pjsip_call_id: Option<i32>,
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

#[derive(Debug, Clone)]
struct CallHistoryEntry {
    call_id: u32,
    account_id: String,
    uri: String,
    direction: String,
    started_at: u64,
    ended_at: u64,
    duration_secs: u64,
    end_state: String,
}

#[derive(Debug, Clone)]
struct MediaStats {
    call_id: u32,
    jitter_ms: f32,
    packet_loss_pct: f32,
    codec: String,
    bitrate_kbps: u32,
}

#[derive(Debug, Clone)]
struct AudioDevice {
    id: u32,
    name: String,
    kind: AudioDeviceKind,
}

#[derive(Debug, Clone, PartialEq)]
enum AudioDeviceKind {
    Input,
    Output,
}

impl AudioDeviceKind {
    fn as_str(&self) -> &str {
        match self {
            Self::Input => "Input",
            Self::Output => "Output",
        }
    }
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

// ---------------------------------------------------------------------------
// PJSIP shim FFI — the C shim (src/shim/pjsip_shim.c) wraps pjsua so that
// every call from Rust goes through a thin, stable C boundary.
// ---------------------------------------------------------------------------

extern "C" {
    fn pd_init(
        user_agent: *const c_char,
        stun_server: *const c_char,
        on_reg: extern "C" fn(i32, i32, i32, *const c_char),
        on_incoming: extern "C" fn(i32, i32, *const c_char),
        on_call: extern "C" fn(i32, i32, i32),
        on_media: extern "C" fn(i32, i32),
        on_log: extern "C" fn(i32, *const c_char),
        on_sip_msg: extern "C" fn(i32, i32, *const c_char),
    ) -> i32;
    fn pd_shutdown() -> i32;
    fn pd_acc_add(
        sip_uri: *const c_char,
        registrar: *const c_char,
        username: *const c_char,
        password: *const c_char,
        auth_username: *const c_char,
        sip_proxy: *const c_char,
        use_tcp: i32,
    ) -> i32;
    fn pd_acc_remove(acc_id: i32) -> i32;
    fn pd_call_make(acc_id: i32, dst_uri: *const c_char) -> i32;
    fn pd_call_answer(call_id: i32) -> i32;
    fn pd_call_hangup(call_id: i32) -> i32;
    fn pd_call_hold(call_id: i32, hold: i32) -> i32;
    fn pd_call_set_mute(call_id: i32, mute: i32) -> i32;
    fn pd_aud_dev_count() -> u32;
    fn pd_aud_dev_info(
        idx: u32,
        id_out: *mut i32,
        name_buf: *mut c_char,
        name_len: i32,
        kind_out: *mut i32,
    ) -> i32;
    fn pd_aud_set_devs(capture_id: i32, playback_id: i32) -> i32;
    fn pd_aud_get_devs(capture_id_out: *mut i32, playback_id_out: *mut i32) -> i32;
    fn pd_call_get_stream_stat(
        call_id: i32,
        jitter_ms_out: *mut f32,
        loss_pct_out: *mut f32,
        codec_buf: *mut c_char,
        codec_buf_len: i32,
        bitrate_kbps_out: *mut i32,
    ) -> i32;
    fn pd_call_send_dtmf(call_id: i32, digits: *const c_char) -> i32;
}

// ---------------------------------------------------------------------------
// PJSIP → Rust callbacks (called from PJSIP worker threads)
// ---------------------------------------------------------------------------

/// Map a PJSIP log level (1–6) to our LogLevel.
fn pj_level_to_log_level(pj_level: i32) -> LogLevel {
    match pj_level {
        1 => LogLevel::Error,
        2 => LogLevel::Warn,
        3 => LogLevel::Info,
        _ => LogLevel::Debug,
    }
}

/// PJSIP log forwarding callback.
extern "C" fn pjsip_on_log(pj_level: i32, msg_ptr: *const c_char) {
    if msg_ptr.is_null() {
        return;
    }
    let msg = unsafe {
        match CStr::from_ptr(msg_ptr).to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return,
        }
    };
    log_engine(pj_level_to_log_level(pj_level), &msg);
}

/// PJSIP registration-state callback.
/// Maps pjsua registration info to our RegistrationState and pushes an event.
extern "C" fn pjsip_on_reg_state(
    pj_acc_id: i32,
    expires: i32,
    status_code: i32,
    reason_ptr: *const c_char,
) {
    let reason = if reason_ptr.is_null() {
        String::new()
    } else {
        unsafe {
            match CStr::from_ptr(reason_ptr).to_str() {
                Ok(s) => s.to_owned(),
                Err(_) => {
                    log_engine(
                        LogLevel::Warn,
                        "pjsip_on_reg_state: reason contains invalid UTF-8",
                    );
                    "<invalid UTF-8>".to_owned()
                }
            }
        }
    };

    // Look up our account string id from the PJSIP integer id
    let account_id = {
        let map = PJSIP_ACC_MAP.lock().unwrap();
        map.get(&pj_acc_id).cloned()
    };
    let account_id = match account_id {
        Some(id) => id,
        None => {
            log_engine(
                LogLevel::Warn,
                &format!("pjsip_on_reg_state: unknown pj_acc_id={pj_acc_id}"),
            );
            return;
        }
    };

    let new_state = if expires > 0 && (status_code == 200 || status_code == 0) {
        RegistrationState::Registered
    } else if status_code >= 400 || (expires == 0 && status_code != 0) {
        RegistrationState::Failed(format!("{status_code} {reason}"))
    } else {
        RegistrationState::Unregistered
    };

    {
        let mut accts = ACCOUNTS.lock().unwrap();
        if let Some(a) = accts.iter_mut().find(|a| a.uuid == account_id) {
            a.reg_state = new_state.clone();
        }
    }
    push_reg_state(&account_id, &new_state);
    log_engine(
        LogLevel::Info,
        &format!(
            "Account '{account_id}' registration: {} (expires={expires}, code={status_code})",
            new_state.variant_name()
        ),
    );
}

/// PJSIP incoming-call callback.
/// Creates a new Call entry with Incoming direction and pushes a Ringing event.
extern "C" fn pjsip_on_incoming_call(pj_acc_id: i32, pj_call_id: i32, from_uri_ptr: *const c_char) {
    let from_uri = if from_uri_ptr.is_null() {
        "sip:unknown".to_owned()
    } else {
        unsafe {
            CStr::from_ptr(from_uri_ptr)
                .to_str()
                .unwrap_or("sip:unknown")
                .to_owned()
        }
    };

    let account_id = {
        let map = PJSIP_ACC_MAP.lock().unwrap();
        map.get(&pj_acc_id).cloned()
    };
    let account_id = match account_id {
        Some(id) => id,
        None => {
            log_engine(
                LogLevel::Warn,
                &format!("pjsip_on_incoming_call: unknown pj_acc_id={pj_acc_id}"),
            );
            return;
        }
    };

    let our_call_id = NEXT_CALL_ID.fetch_add(1, Ordering::SeqCst);
    let call = Call {
        id: our_call_id,
        account_id: account_id.clone(),
        uri: from_uri.clone(),
        direction: CallDirection::Incoming,
        state: CallState::Ringing,
        muted: false,
        on_hold: false,
        started_at: now_secs(),
        accumulated_active_secs: 0,
        last_resumed_at: None,
        pjsip_call_id: Some(pj_call_id),
    };

    push_call_state(&call);
    CALLS.lock().unwrap().push(call);
    PJSIP_CALL_MAP
        .lock()
        .unwrap()
        .insert(pj_call_id, our_call_id);

    log_engine(
        LogLevel::Info,
        &format!(
            "Incoming call id={our_call_id} pj_call={pj_call_id} from={from_uri} account={account_id}"
        ),
    );
}

/// PJSIP call-state callback.
/// Maps pjsip_inv_state to CallState and updates/pushes accordingly.
extern "C" fn pjsip_on_call_state(pj_call_id: i32, inv_state: i32, _status_code: i32) {
    // pjsip_inv_state: 0=NULL 1=CALLING 2=INCOMING 3=EARLY 4=CONNECTING 5=CONFIRMED 6=DISCONNECTED
    let new_state = match inv_state {
        0 | 1 | 2 | 3 => CallState::Ringing,
        4 | 5 => CallState::InCall,
        6 => CallState::Ended,
        _ => return,
    };

    let our_call_id = {
        let map = PJSIP_CALL_MAP.lock().unwrap();
        map.get(&pj_call_id).copied()
    };
    let our_call_id = match our_call_id {
        Some(id) => id,
        None => {
            log_engine(
                LogLevel::Debug,
                &format!("pjsip_on_call_state: unknown pj_call_id={pj_call_id}"),
            );
            return;
        }
    };

    let should_record_history = new_state == CallState::Ended;

    {
        let mut calls = CALLS.lock().unwrap();
        if let Some(call) = calls.iter_mut().find(|c| c.id == our_call_id) {
            let old_state = call.state.clone();
            call.state = new_state.clone();

            // Transition logic for duration tracking
            if new_state == CallState::InCall && old_state != CallState::InCall {
                call.last_resumed_at = Some(now_secs());
            } else if (new_state == CallState::Ended || new_state == CallState::OnHold)
                && old_state == CallState::InCall
            {
                if let Some(resumed_at) = call.last_resumed_at.take() {
                    call.accumulated_active_secs += now_secs().saturating_sub(resumed_at);
                }
            }

            push_call_state(call);

            if should_record_history {
                let ended_at = now_secs();
                let entry = CallHistoryEntry {
                    call_id: call.id,
                    account_id: call.account_id.clone(),
                    uri: call.uri.clone(),
                    direction: call.direction.variant_name().to_owned(),
                    started_at: call.started_at,
                    ended_at,
                    duration_secs: call.accumulated_active_secs,
                    end_state: "Ended".to_owned(),
                };
                CALL_HISTORY.lock().unwrap().push(entry);
                MEDIA_STATS.lock().unwrap().remove(&our_call_id);
            }
        }
    }

    if should_record_history {
        // Remove from PJSIP call map
        PJSIP_CALL_MAP.lock().unwrap().remove(&pj_call_id);
    }
}

/// PJSIP call-media callback.
/// Called when audio media becomes active or inactive for a call.
/// When active=1, also polls stream stats and pushes a MediaStatsUpdated event.
extern "C" fn pjsip_on_call_media(pj_call_id: i32, active: i32) {
    let our_call_id = {
        let map = PJSIP_CALL_MAP.lock().unwrap();
        map.get(&pj_call_id).copied()
    };

    if let Some(cid) = our_call_id {
        let mut calls = CALLS.lock().unwrap();
        if let Some(call) = calls.iter_mut().find(|c| c.id == cid) {
            let old_on_hold = call.on_hold;

            if active != 0 {
                // Media is active
                // Sticky behavior: re-apply mute if user set it before stream was ready
                if call.muted {
                    unsafe { pd_call_set_mute(pj_call_id, 1) };
                }

                if call.on_hold {
                    // User wanted hold, but media just became active (e.g. call connected)
                    // Re-apply hold to stay in hold state
                    unsafe { pd_call_hold(pj_call_id, 1) };
                    call.state = CallState::OnHold;
                } else {
                    call.state = CallState::InCall;
                    if old_on_hold {
                        call.last_resumed_at = Some(now_secs());
                    }
                }
            } else {
                // Media is inactive (On Hold)
                call.on_hold = true;
                call.state = CallState::OnHold;
                if let Some(resumed_at) = call.last_resumed_at.take() {
                    call.accumulated_active_secs += now_secs().saturating_sub(resumed_at);
                }
            }
            push_call_state(call);
        }
    }

    if active != 0 {
        pjsip_poll_media_stats(pj_call_id);
    }
}

/// PJSIP SIP-message capture callback.
extern "C" fn pjsip_on_sip_msg(pj_call_id: i32, is_tx: i32, msg_ptr: *const c_char) {
    if msg_ptr.is_null() {
        return;
    }
    let raw = unsafe {
        match CStr::from_ptr(msg_ptr).to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return,
        }
    };
    let masked = mask_sip_log(&raw);
    let direction = if is_tx != 0 { "send" } else { "recv" };

    // Use serde_json for proper escaping of SIP message content
    // (multi-line messages, quotes, backslashes, etc.)
    let event = serde_json::json!({
        "type": "SipMessageCaptured",
        "payload": {
            "call_id": pj_call_id,
            "direction": direction,
            "raw": masked,
        }
    });
    push_event(event.to_string());
}

/// Poll real-time media statistics for a PJSIP call and push a MediaStatsUpdated event.
fn pjsip_poll_media_stats(pj_call_id: i32) {
    let our_call_id = {
        let map = PJSIP_CALL_MAP.lock().unwrap();
        match map.get(&pj_call_id).copied() {
            Some(id) => id,
            None => return,
        }
    };

    let mut jitter_ms: f32 = 0.0;
    let mut loss_pct: f32 = 0.0;
    let mut codec_buf = [0u8; 64];
    let mut bitrate: i32 = 64;

    let rc = unsafe {
        pd_call_get_stream_stat(
            pj_call_id,
            &mut jitter_ms,
            &mut loss_pct,
            codec_buf.as_mut_ptr() as *mut c_char,
            codec_buf.len() as i32,
            &mut bitrate,
        )
    };
    if rc != 0 {
        return;
    }

    let codec = unsafe {
        CStr::from_ptr(codec_buf.as_ptr() as *const c_char)
            .to_str()
            .unwrap_or("unknown")
            .to_owned()
    };

    let stats = MediaStats {
        call_id: our_call_id,
        jitter_ms,
        packet_loss_pct: loss_pct,
        codec: codec.clone(),
        bitrate_kbps: bitrate as u32,
    };
    push_media_stats(&stats);
    MEDIA_STATS.lock().unwrap().insert(our_call_id, stats);
}

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------

/// Append a log entry to the ring buffer and, if the entry's level is at or
/// above the active threshold, push an `EngineLog` event to the event queue.
fn log_engine(level: LogLevel, message: &str) {
    let ts = now_secs();
    let active = LogLevel::from_u8(ACTIVE_LOG_LEVEL.load(Ordering::Relaxed));
    let entry = LogEntry {
        level,
        message: message.to_owned(),
        ts,
    };

    // Always buffer the entry (regardless of active level) so callers of
    // GetLogBuffer see the full history.
    if let Ok(mut buf) = LOG_BUFFER.lock().or_else(|e| Ok::<_, ()>(e.into_inner())) {
        if buf.len() >= LOG_BUFFER_MAX {
            buf.pop_front();
        }
        buf.push_back(entry);
    }

    // Only emit the event if the level meets the active filter.
    if level <= active {
        let msg_escaped = message
            .replace('\\', "\\\\")
            .replace('"', "\\\"")
            .replace('\n', "\\n")
            .replace('\r', "\\r");
        push_event(format!(
            r#"{{"type":"EngineLog","payload":{{"level":"{}","message":"{msg_escaped}","ts":{ts}}}}}"#,
            level.as_str()
        ));
    }
}

/// Mask sensitive values from a SIP header string.
/// Replaces the value of Authorization and Proxy-Authorization headers,
/// and any sip: URI that contains a password (user:pass@host).
pub fn mask_sip_log(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for line in input.lines() {
        let lower = line.to_lowercase();
        if lower.starts_with("authorization:") || lower.starts_with("proxy-authorization:") {
            // Keep the header name, redact everything after the colon
            if let Some(colon) = line.find(':') {
                out.push_str(&line[..=colon]);
                out.push_str(" ***MASKED***");
            } else {
                out.push_str(line);
            }
        } else if lower.contains("sip:") && line.contains('@') && line.contains(':') {
            // Mask password portion in sip:user:password@host URIs
            out.push_str(&mask_sip_uri_passwords(line));
        } else {
            out.push_str(line);
        }
        out.push('\n');
    }
    // Remove trailing newline added by the loop if input didn't end with one
    if !input.ends_with('\n') && out.ends_with('\n') {
        out.pop();
    }
    out
}

/// Replace `sip:user:password@host` with `sip:user:***@host` in [s].
fn mask_sip_uri_passwords(s: &str) -> String {
    let mut result = String::new();
    let mut remaining = s;
    while let Some(start) = remaining.to_lowercase().find("sip:") {
        result.push_str(&remaining[..start]);
        let uri_start = &remaining[start..];
        // Find end of URI (whitespace or end of string)
        let uri_end = uri_start
            .find(|c: char| c.is_whitespace() || c == '>' || c == '<' || c == '"')
            .unwrap_or(uri_start.len());
        let uri = &uri_start[..uri_end];
        result.push_str(&mask_single_uri(uri));
        remaining = &uri_start[uri_end..];
    }
    result.push_str(remaining);
    result
}

fn mask_single_uri(uri: &str) -> String {
    // sip:user:password@host  →  sip:user:***@host
    // sip:user@host           →  unchanged
    let body = if uri.to_lowercase().starts_with("sip:") {
        &uri[4..]
    } else if uri.to_lowercase().starts_with("sips:") {
        &uri[5..]
    } else {
        return uri.to_owned();
    };
    let prefix = &uri[..uri.len() - body.len()];
    // body is user[:password]@host[:port][;params]
    if let Some(at_pos) = body.find('@') {
        let userinfo = &body[..at_pos];
        let hostinfo = &body[at_pos..];
        if let Some(colon_pos) = userinfo.find(':') {
            // Has password — mask it
            format!("{}{}:***{}", prefix, &userinfo[..colon_pos], hostinfo)
        } else {
            uri.to_owned()
        }
    } else {
        uri.to_owned()
    }
}

// ---------------------------------------------------------------------------
// Event helpers
// ---------------------------------------------------------------------------

/// Parse event JSON and invoke the structured event callback.
/// The JSON format is: {"type":"EventType","payload":{...}}
fn push_event(json: String) {
    // Parse the event type and forward to callback
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(&json) {
        if let Some(event_type) = v["type"].as_str() {
            let event_id = match event_type {
                "EngineReady" => EngineEventId::EngineReady,
                "RegistrationStateChanged" => EngineEventId::RegistrationStateChanged,
                "CallStateChanged" => EngineEventId::CallStateChanged,
                "MediaStatsUpdated" => EngineEventId::MediaStatsUpdated,
                "AudioDeviceList" => EngineEventId::AudioDeviceList,
                "AudioDevicesSet" => EngineEventId::AudioDevicesSet,
                "CallHistoryResult" => EngineEventId::CallHistoryResult,
                "SipMessageCaptured" => EngineEventId::SipMessageCaptured,
                "DiagBundleReady" => EngineEventId::DiagBundleReady,
                "AccountSecurityUpdated" => EngineEventId::AccountSecurityUpdated,
                "CredStored" => EngineEventId::CredStored,
                "CredRetrieved" => EngineEventId::CredRetrieved,
                "EnginePong" => EngineEventId::EnginePong,
                "LogLevelSet" => EngineEventId::LogLevelSet,
                "LogBufferResult" => EngineEventId::LogBufferResult,
                "EngineLog" => EngineEventId::EngineLog,
                _ => {
                    // Even if unknown to the internal enum, we still broadcast to IPC
                    broadcast_ipc(json);
                    return;
                }
            };
            // Extract payload and pass as JSON string
            if let Some(payload) = v.get("payload") {
                if let Ok(payload_json) = serde_json::to_string(payload) {
                    invoke_event_callback(event_id, &payload_json);
                }
            }
        }
    }
    // Broadcast original JSON to all IPC listeners (CLI, PD, etc)
    broadcast_ipc(json);
}

fn broadcast_ipc(json: String) {
    let mut senders = CLIENT_SENDERS.lock().unwrap();
    senders.retain(|s| s.send(json.clone()).is_ok());
}

fn push_reg_state(account_id: &str, state: &RegistrationState) {
    let (account_name, display_name) = if let Ok(accts) = ACCOUNTS.lock() {
        if let Some(a) = accts.iter().find(|a| a.uuid == account_id) {
            (a.account_name.clone(), a.display_name.clone())
        } else {
            ("".to_owned(), "".to_owned())
        }
    } else {
        ("".to_owned(), "".to_owned())
    };

    let reason = match state {
        RegistrationState::Failed(r) => r.as_str(),
        _ => "",
    };
    push_event(format!(
        r#"{{"type":"RegistrationStateChanged","payload":{{"account_id":"{account_id}","account_name":"{account_name}","display_name":"{display_name}","state":"{}","reason":"{reason}"}}}}"#,
        state.variant_name()
    ));
}

fn push_call_state(call: &Call) {
    let last_resumed_at_val = call
        .last_resumed_at
        .map(|v| v.to_string())
        .unwrap_or_else(|| "null".to_owned());
    push_event(format!(
        r#"{{"type":"CallStateChanged","payload":{{"call_id":{},"account_id":"{}","uri":"{}","direction":"{}","state":"{}","muted":{},"on_hold":{},"accumulated_active_secs":{},"last_resumed_at":{}}}}}"#,
        call.id,
        call.account_id,
        call.uri,
        call.direction.variant_name(),
        call.state.variant_name(),
        call.muted,
        call.on_hold,
        call.accumulated_active_secs,
        last_resumed_at_val
    ));
}

fn push_media_stats(stats: &MediaStats) {
    push_event(format!(
        r#"{{"type":"MediaStatsUpdated","payload":{{"call_id":{},"jitter_ms":{:.1},"packet_loss_pct":{:.1},"codec":"{}","bitrate_kbps":{}}}}}"#,
        stats.call_id, stats.jitter_ms, stats.packet_loss_pct, stats.codec, stats.bitrate_kbps
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
        "AccountSetSecurity" => cmd_account_set_security(payload),
        "CallStart" => cmd_call_start(payload),
        "CallAnswer" => cmd_call_answer(payload),
        "CallHangup" => cmd_call_hangup(payload),
        "CallMute" => cmd_call_mute(payload),
        "CallHold" => cmd_call_hold(payload),
        "CallSendDtmf" => cmd_call_send_dtmf(payload),
        "MediaStatsUpdate" => cmd_media_stats_update(payload),
        "AudioListDevices" => cmd_audio_list_devices(payload),
        "AudioSetDevices" => cmd_audio_set_devices(payload),
        "CallHistoryQuery" => cmd_call_history_query(payload),
        "SipCaptureMessage" => cmd_sip_capture(payload),
        "DiagExportBundle" => cmd_diag_export(payload),
        "CredStore" => cmd_cred_store(payload),
        "CredRetrieve" => cmd_cred_retrieve(payload),
        "EnginePing" => cmd_engine_ping(payload),
        "SetLogLevel" => cmd_set_log_level(payload),
        "GetLogBuffer" => cmd_get_log_buffer(payload),
        _ => EngineErrorCode::UnknownCommand,
    }
}

fn cmd_account_upsert(p: &serde_json::Value) -> EngineErrorCode {
    let uuid = match p["uuid"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let mut accts = ACCOUNTS.lock().unwrap();
    if let Some(existing) = accts.iter_mut().find(|a| a.uuid == uuid) {
        existing.account_name = p["account_name"].as_str().unwrap_or("").to_owned();
        existing.display_name = p["display_name"].as_str().unwrap_or("").to_owned();
        existing.server = p["server"].as_str().unwrap_or("").to_owned();
        existing.sip_proxy = p["sip_proxy"].as_str().unwrap_or("").to_owned();
        existing.username = p["username"].as_str().unwrap_or("").to_owned();
        existing.auth_username = p["auth_username"].as_str().unwrap_or("").to_owned();
        existing.domain = p["domain"].as_str().unwrap_or("").to_owned();
        existing.password = p["password"].as_str().unwrap_or("").to_owned();
        existing.transport = p["transport"].as_str().unwrap_or("udp").to_owned();
        existing.stun_server = p["stun_server"].as_str().unwrap_or("").to_owned();
        existing.turn_server = p["turn_server"].as_str().unwrap_or("").to_owned();
        existing.tls_enabled = p["tls_enabled"].as_bool().unwrap_or(existing.tls_enabled);
        existing.srtp_enabled = p["srtp_enabled"].as_bool().unwrap_or(existing.srtp_enabled);
    } else {
        let acct = Account {
            uuid: uuid.clone(),
            account_name: p["account_name"].as_str().unwrap_or("").to_owned(),
            display_name: p["display_name"].as_str().unwrap_or("").to_owned(),
            server: p["server"].as_str().unwrap_or("").to_owned(),
            sip_proxy: p["sip_proxy"].as_str().unwrap_or("").to_owned(),
            username: p["username"].as_str().unwrap_or("").to_owned(),
            auth_username: p["auth_username"].as_str().unwrap_or("").to_owned(),
            domain: p["domain"].as_str().unwrap_or("").to_owned(),
            password: p["password"].as_str().unwrap_or("").to_owned(),
            transport: p["transport"].as_str().unwrap_or("udp").to_owned(),
            stun_server: p["stun_server"].as_str().unwrap_or("").to_owned(),
            turn_server: p["turn_server"].as_str().unwrap_or("").to_owned(),
            tls_enabled: p["tls_enabled"].as_bool().unwrap_or(false),
            srtp_enabled: p["srtp_enabled"].as_bool().unwrap_or(false),
            reg_state: RegistrationState::Unregistered,
            pjsip_acc_id: None,
        };
        accts.push(acct);
        drop(accts);
        push_reg_state(&uuid, &RegistrationState::Unregistered);
    }
    EngineErrorCode::Ok
}

fn cmd_account_register(p: &serde_json::Value) -> EngineErrorCode {
    let id = match p["uuid"].as_str().or_else(|| p["id"].as_str()) {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };

    // Snapshot account config for PJSIP (need it outside the lock)
    let acct_snapshot = {
        let accts = ACCOUNTS.lock().unwrap();
        match accts.iter().find(|a| a.uuid == id) {
            None => {
                log_engine(
                    LogLevel::Error,
                    &format!("AccountRegister: account '{id}' not found"),
                );
                return EngineErrorCode::NotFound;
            }
            Some(a) => a.clone(),
        }
    };

    // Transition to Registering state
    {
        let mut accts = ACCOUNTS.lock().unwrap();
        if let Some(a) = accts.iter_mut().find(|a| a.uuid == id) {
            // Remove any existing PJSIP account so we start fresh
            if let Some(old_pj_id) = a.pjsip_acc_id.take() {
                unsafe { pd_acc_remove(old_pj_id) };
                PJSIP_ACC_MAP.lock().unwrap().remove(&old_pj_id);
            }
            a.reg_state = RegistrationState::Registering;
        }
    }
    push_event(format!(
        r#"{{"type":"RegistrationStateChanged","payload":{{"account_id":"{id}","account_name":"{}","display_name":"{}","state":"Registering","reason":""}}}}"#,
        acct_snapshot.account_name, acct_snapshot.display_name
    ));

    // --- PJSIP registration ---
    {
        let use_tcp = if acct_snapshot.transport.eq_ignore_ascii_case("tcp") {
            1i32
        } else {
            0i32
        };

        // Build SIP URI: sip:username@server  (use sips: if TLS enabled)
        let scheme = if acct_snapshot.tls_enabled {
            "sips"
        } else {
            "sip"
        };
        // Use domain for SIP URI if provided, otherwise use server
        let uri_domain = if !acct_snapshot.domain.is_empty() {
            &acct_snapshot.domain
        } else {
            &acct_snapshot.server
        };

        let sip_uri_str = format!("{}:{}@{}", scheme, acct_snapshot.username, uri_domain);
        let registrar_str = format!("sip:{}", acct_snapshot.server);

        let sip_uri = match CString::new(sip_uri_str) {
            Ok(s) => s,
            Err(_) => {
                log_engine(
                    LogLevel::Error,
                    &format!("Account '{id}': SIP URI contains NUL byte"),
                );
                return EngineErrorCode::InternalError;
            }
        };
        let registrar = match CString::new(registrar_str) {
            Ok(s) => s,
            Err(_) => {
                log_engine(
                    LogLevel::Error,
                    &format!("Account '{id}': registrar URI contains NUL byte"),
                );
                return EngineErrorCode::InternalError;
            }
        };
        let username = match CString::new(acct_snapshot.username.clone()) {
            Ok(s) => s,
            Err(_) => {
                log_engine(
                    LogLevel::Error,
                    &format!("Account '{id}': username contains NUL byte"),
                );
                return EngineErrorCode::InternalError;
            }
        };
        let password = match CString::new(acct_snapshot.password.clone()) {
            Ok(s) => s,
            Err(_) => {
                log_engine(
                    LogLevel::Error,
                    &format!("Account '{id}': password contains NUL byte"),
                );
                return EngineErrorCode::InternalError;
            }
        };
        let auth_username = match CString::new(acct_snapshot.auth_username.clone()) {
            Ok(s) => s,
            Err(_) => {
                log_engine(
                    LogLevel::Error,
                    &format!("Account '{id}': auth_username contains NUL byte"),
                );
                return EngineErrorCode::InternalError;
            }
        };
        let sip_proxy = match CString::new(acct_snapshot.sip_proxy.clone()) {
            Ok(s) => s,
            Err(_) => {
                log_engine(
                    LogLevel::Error,
                    &format!("Account '{id}': sip_proxy contains NUL byte"),
                );
                return EngineErrorCode::InternalError;
            }
        };

        let pj_acc_id = unsafe {
            pd_acc_add(
                sip_uri.as_ptr(),
                registrar.as_ptr(),
                username.as_ptr(),
                password.as_ptr(),
                auth_username.as_ptr(),
                sip_proxy.as_ptr(),
                use_tcp,
            )
        };

        if pj_acc_id < 0 {
            let fail = RegistrationState::Failed("pd_acc_add failed".to_owned());
            let mut accts = ACCOUNTS.lock().unwrap();
            if let Some(a) = accts.iter_mut().find(|a| a.uuid == id) {
                a.reg_state = fail.clone();
            }
            push_reg_state(&id, &fail);
            log_engine(
                LogLevel::Error,
                &format!("Account '{id}': pd_acc_add returned error"),
            );
            return EngineErrorCode::InternalError;
        }

        // Store the PJSIP account id for future operations
        {
            let mut accts = ACCOUNTS.lock().unwrap();
            if let Some(a) = accts.iter_mut().find(|a| a.uuid == id) {
                a.pjsip_acc_id = Some(pj_acc_id);
            }
        }
        PJSIP_ACC_MAP.lock().unwrap().insert(pj_acc_id, id.clone());
        log_engine(
            LogLevel::Info,
            &format!("Account '{id}' registering via PJSIP (pj_acc_id={pj_acc_id})"),
        );
        // on_reg_state callback will push the final Registered / Failed event
        return EngineErrorCode::Ok;
    }
}

fn cmd_account_unregister(p: &serde_json::Value) -> EngineErrorCode {
    let id = match p["uuid"].as_str().or_else(|| p["id"].as_str()) {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let mut accts = ACCOUNTS.lock().unwrap();
    match accts.iter_mut().find(|a| a.uuid == id) {
        None => EngineErrorCode::NotFound,
        Some(acct) => {
            // Remove from PJSIP (triggers SIP unregistration)
            if let Some(pj_id) = acct.pjsip_acc_id.take() {
                unsafe { pd_acc_remove(pj_id) };
                PJSIP_ACC_MAP.lock().unwrap().remove(&pj_id);
                log_engine(
                    LogLevel::Info,
                    &format!("Account '{id}' unregistered via PJSIP (pj_acc_id={pj_id})"),
                );
            }
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
        None => {
            // Pick first registered account if none specified
            let accts = ACCOUNTS.lock().unwrap();
            match accts.iter().find(|a| a.pjsip_acc_id.is_some()) {
                Some(a) => a.uuid.clone(),
                None => {
                    log_engine(
                        LogLevel::Warn,
                        "CallStart: No account specified and no registered accounts found",
                    );
                    return EngineErrorCode::NotFound;
                }
            }
        }
    };
    let uri = match p["uri"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let call_id = NEXT_CALL_ID.fetch_add(1, Ordering::SeqCst);
    log_engine(
        LogLevel::Debug,
        &format!("CallStart: call_id={call_id} uri={uri} account={account_id}"),
    );

    // --- PJSIP call ---
    {
        let pj_acc_id = {
            let accts = ACCOUNTS.lock().unwrap();
            accts
                .iter()
                .find(|a| a.uuid == account_id)
                .and_then(|a| a.pjsip_acc_id)
        };
        let pj_acc_id = match pj_acc_id {
            Some(id) => id,
            None => {
                log_engine(
                    LogLevel::Error,
                    &format!("CallStart: account '{account_id}' not registered with PJSIP"),
                );
                return EngineErrorCode::NotFound;
            }
        };
        let dst = match CString::new(uri.clone()) {
            Ok(s) => s,
            Err(_) => {
                log_engine(
                    LogLevel::Error,
                    &format!("CallStart: destination URI contains NUL byte: {uri}"),
                );
                return EngineErrorCode::InternalError;
            }
        };
        let pj_call_id = unsafe { pd_call_make(pj_acc_id, dst.as_ptr()) };
        if pj_call_id < 0 {
            log_engine(
                LogLevel::Error,
                &format!("CallStart: pd_call_make failed for uri={uri}"),
            );
            return EngineErrorCode::InternalError;
        }
        let call = Call {
            id: call_id,
            account_id: account_id.clone(),
            uri: uri.clone(),
            direction: CallDirection::Outgoing,
            state: CallState::Ringing,
            muted: false,
            on_hold: false,
            started_at: now_secs(),
            accumulated_active_secs: 0,
            last_resumed_at: None,
            pjsip_call_id: Some(pj_call_id),
        };
        push_call_state(&call);
        CALLS.lock().unwrap().push(call);
        PJSIP_CALL_MAP.lock().unwrap().insert(pj_call_id, call_id);
        log_engine(
            LogLevel::Info,
            &format!("Outgoing call id={call_id} pj_call={pj_call_id} uri={uri}"),
        );
        return EngineErrorCode::Ok;
    }
}

fn cmd_call_answer(p: &serde_json::Value) -> EngineErrorCode {
    let mut calls_guard = CALLS.lock().unwrap();
    let call_id = match p["call_id"].as_u64() {
        Some(n) => Some(n as u32),
        None => {
            // Find first ringing incoming call
            calls_guard
                .iter()
                .find(|c| {
                    c.state == CallState::Ringing && matches!(c.direction, CallDirection::Incoming)
                })
                .map(|c| c.id)
        }
    };
    let call_id = match call_id {
        Some(id) => id,
        None => return EngineErrorCode::NotFound,
    };

    match calls_guard.iter_mut().find(|c| c.id == call_id) {
        None => EngineErrorCode::NotFound,
        Some(call) => {
            // Answer via PJSIP shim
            match call.pjsip_call_id {
                Some(pj_id) => {
                    let rc = unsafe { pd_call_answer(pj_id) };
                    if rc != 0 {
                        log_engine(
                            LogLevel::Warn,
                            &format!("CallAnswer: pd_call_answer({pj_id}) rc={rc}"),
                        );
                    }
                    // State will be updated via on_call_state callback
                    EngineErrorCode::Ok
                }
                None => {
                    log_engine(
                        LogLevel::Error,
                        &format!("CallAnswer: call {call_id} has no PJSIP call id"),
                    );
                    EngineErrorCode::NotFound
                }
            }
        }
    }
}

fn cmd_call_hangup(p: &serde_json::Value) -> EngineErrorCode {
    let pj_id = {
        let calls_guard = CALLS.lock().unwrap();
        let call_id = match p["call_id"].as_u64() {
            Some(n) => Some(n as u32),
            None => calls_guard
                .iter()
                .find(|c| c.state != CallState::Ended)
                .map(|c| c.id),
        };
        match call_id {
            Some(id) => calls_guard
                .iter()
                .find(|c| c.id == id)
                .and_then(|c| c.pjsip_call_id),
            None => return EngineErrorCode::NotFound,
        }
    };

    match pj_id {
        Some(pj_id) => {
            // Hang up via PJSIP shim - NO LOCK HELD during external call
            let rc = unsafe { pd_call_hangup(pj_id) };
            if rc != 0 {
                log_engine(
                    LogLevel::Warn,
                    &format!("CallHangup: pd_call_hangup({pj_id}) rc={rc}"),
                );
            }
            EngineErrorCode::Ok
        }
        None => {
            // If we found a call_id but no pjsip_id, it might already be ended or not yet wired
            EngineErrorCode::NotFound
        }
    }
}

fn cmd_call_mute(p: &serde_json::Value) -> EngineErrorCode {
    let muted = p["muted"].as_bool().unwrap_or(true);
    let pj_id_opt = {
        let mut calls_guard = CALLS.lock().unwrap();
        let call_id = match p["call_id"].as_u64() {
            Some(n) => Some(n as u32),
            None => calls_guard
                .iter()
                .find(|c| c.state != CallState::Ended)
                .map(|c| c.id),
        }
        .unwrap_or(0); // fallback or error

        match calls_guard.iter_mut().find(|c| c.id == call_id) {
            None => return EngineErrorCode::NotFound,
            Some(call) => {
                call.muted = muted;
                let pj_id = call.pjsip_call_id;
                push_call_state(call);
                pj_id
            }
        }
    };

    if let Some(pj_id) = pj_id_opt {
        // Mute via PJSIP - NO LOCK HELD
        unsafe { pd_call_set_mute(pj_id, if muted { 1 } else { 0 }) };
    }
    EngineErrorCode::Ok
}

fn cmd_call_hold(p: &serde_json::Value) -> EngineErrorCode {
    let hold = p["hold"].as_bool().unwrap_or(true);
    let pj_id_opt = {
        let mut calls_guard = CALLS.lock().unwrap();
        let call_id = match p["call_id"].as_u64() {
            Some(n) => Some(n as u32),
            None => calls_guard
                .iter()
                .find(|c| c.state != CallState::Ended)
                .map(|c| c.id),
        }
        .unwrap_or(0);

        match calls_guard.iter_mut().find(|c| c.id == call_id) {
            None => return EngineErrorCode::NotFound,
            Some(call) => {
                call.on_hold = hold;
                // Immediate state update for UI responsiveness
                if hold {
                    call.state = CallState::OnHold;
                    if let Some(resumed_at) = call.last_resumed_at.take() {
                        call.accumulated_active_secs += now_secs().saturating_sub(resumed_at);
                    }
                } else {
                    call.state = CallState::InCall;
                }
                push_call_state(call);
                call.pjsip_call_id
            }
        }
    };

    if let Some(pj_id) = pj_id_opt {
        // Hold via PJSIP re-INVITE - NO LOCK HELD
        unsafe { pd_call_hold(pj_id, if hold { 1 } else { 0 }) };
    }
    EngineErrorCode::Ok
}

fn cmd_media_stats_update(p: &serde_json::Value) -> EngineErrorCode {
    let call_id = match p["call_id"].as_u64() {
        Some(n) => n as u32,
        None => return EngineErrorCode::InvalidJson,
    };
    let stats = MediaStats {
        call_id,
        jitter_ms: p["jitter_ms"].as_f64().unwrap_or(0.0) as f32,
        packet_loss_pct: p["packet_loss_pct"].as_f64().unwrap_or(0.0) as f32,
        codec: p["codec"].as_str().unwrap_or("PCMU").to_owned(),
        bitrate_kbps: p["bitrate_kbps"].as_u64().unwrap_or(64) as u32,
    };
    push_media_stats(&stats);
    MEDIA_STATS.lock().unwrap().insert(call_id, stats);
    EngineErrorCode::Ok
}

fn cmd_audio_list_devices(_p: &serde_json::Value) -> EngineErrorCode {
    // Enumerate real audio devices via PJSIP
    {
        let count = unsafe { pd_aud_dev_count() };
        let mut real_devices: Vec<AudioDevice> = Vec::new();
        for idx in 0..count {
            let mut id: i32 = 0;
            let mut name_buf = [0u8; 128];
            let mut kind: i32 = 0;
            let rc = unsafe {
                pd_aud_dev_info(
                    idx,
                    &mut id,
                    name_buf.as_mut_ptr() as *mut c_char,
                    name_buf.len() as i32,
                    &mut kind,
                )
            };
            if rc != 0 {
                continue;
            }
            let name = unsafe {
                CStr::from_ptr(name_buf.as_ptr() as *const c_char)
                    .to_str()
                    .unwrap_or("Unknown")
                    .to_owned()
            };
            // kind: 0=input, 1=output, 2=both → emit two entries for "both"
            if kind == 0 || kind == 2 {
                real_devices.push(AudioDevice {
                    id: id as u32,
                    name: name.clone(),
                    kind: AudioDeviceKind::Input,
                });
            }
            if kind == 1 || kind == 2 {
                real_devices.push(AudioDevice {
                    id: id as u32,
                    name: name.clone(),
                    kind: AudioDeviceKind::Output,
                });
            }
        }
        // Get current selection from PJSIP
        let mut cap: i32 = -1;
        let mut play: i32 = -1;
        unsafe { pd_aud_get_devs(&mut cap, &mut play) };
        let selected_in = if cap >= 0 { cap as u32 } else { 0 };
        let selected_out = if play >= 0 { play as u32 } else { 0 };

        *AUDIO_DEVICES.lock().unwrap() = real_devices;
        SELECTED_INPUT.store(selected_in, Ordering::Relaxed);
        SELECTED_OUTPUT.store(selected_out, Ordering::Relaxed);
    }

    // Build and push the event (shared by both paths)
    let devices = AUDIO_DEVICES.lock().unwrap();
    let mut items = String::new();
    for (i, d) in devices.iter().enumerate() {
        if i > 0 {
            items.push(',');
        }
        items.push_str(&format!(
            r#"{{"id":{},"name":"{}","kind":"{}"}}"#,
            d.id,
            d.name,
            d.kind.as_str()
        ));
    }
    let selected_in = SELECTED_INPUT.load(Ordering::Relaxed);
    let selected_out = SELECTED_OUTPUT.load(Ordering::Relaxed);
    push_event(format!(
        r#"{{"type":"AudioDeviceList","payload":{{"devices":[{items}],"selected_input":{selected_in},"selected_output":{selected_out}}}}}"#
    ));
    EngineErrorCode::Ok
}

fn cmd_audio_set_devices(p: &serde_json::Value) -> EngineErrorCode {
    let input_id = match p["input_id"].as_u64() {
        Some(n) => n as u32,
        None => return EngineErrorCode::InvalidJson,
    };
    let output_id = match p["output_id"].as_u64() {
        Some(n) => n as u32,
        None => return EngineErrorCode::InvalidJson,
    };
    let devices = AUDIO_DEVICES.lock().unwrap();
    let has_input = devices
        .iter()
        .any(|d| d.id == input_id && d.kind == AudioDeviceKind::Input);
    let has_output = devices
        .iter()
        .any(|d| d.id == output_id && d.kind == AudioDeviceKind::Output);
    drop(devices);
    if !has_input || !has_output {
        return EngineErrorCode::NotFound;
    }
    // Apply to the sound subsystem
    {
        let rc = unsafe { pd_aud_set_devs(input_id as i32, output_id as i32) };
        if rc != 0 {
            log_engine(
                LogLevel::Warn,
                &format!("AudioSetDevices: pd_aud_set_devs({input_id}, {output_id}) rc={rc}"),
            );
        }
    }
    SELECTED_INPUT.store(input_id, Ordering::Relaxed);
    SELECTED_OUTPUT.store(output_id, Ordering::Relaxed);
    push_event(format!(
        r#"{{"type":"AudioDevicesSet","payload":{{"input_id":{input_id},"output_id":{output_id}}}}}"#
    ));
    EngineErrorCode::Ok
}

fn cmd_call_send_dtmf(p: &serde_json::Value) -> EngineErrorCode {
    let call_id = match p["call_id"].as_u64() {
        Some(v) => v as u32,
        None => return EngineErrorCode::InvalidJson,
    };
    let digits = match p["digits"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };

    log_engine(LogLevel::Info, &format!("Sending DTMF: {digits}"));

    {
        let calls = CALLS.lock().unwrap();
        if let Some(call) = calls.iter().find(|c| c.id == call_id) {
            if let Some(pj_id) = call.pjsip_call_id {
                if let Ok(digits_cstr) = CString::new(digits) {
                    unsafe { pd_call_send_dtmf(pj_id, digits_cstr.as_ptr()) };
                }
            }
        }
    }

    EngineErrorCode::Ok
}

fn cmd_call_history_query(_p: &serde_json::Value) -> EngineErrorCode {
    let history = CALL_HISTORY.lock().unwrap();
    let mut items = String::new();
    for (i, e) in history.iter().enumerate() {
        if i > 0 {
            items.push(',');
        }
        items.push_str(&format!(
            r#"{{"call_id":{},"account_id":"{}","uri":"{}","direction":"{}","started_at":{},"ended_at":{},"duration_secs":{},"end_state":"{}"}}"#,
            e.call_id,
            e.account_id,
            e.uri,
            e.direction,
            e.started_at,
            e.ended_at,
            e.duration_secs,
            e.end_state
        ));
    }
    push_event(format!(
        r#"{{"type":"CallHistoryResult","payload":{{"entries":[{items}]}}}}"#
    ));
    EngineErrorCode::Ok
}

fn cmd_sip_capture(p: &serde_json::Value) -> EngineErrorCode {
    let direction = p["direction"].as_str().unwrap_or("?");
    let raw = p["raw"].as_str().unwrap_or("");
    let masked = mask_sip_log(raw);
    // Escape the masked string for JSON embedding
    let escaped = masked
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r");
    push_event(format!(
        r#"{{"type":"SipMessageCaptured","payload":{{"direction":"{direction}","raw":"{escaped}"}}}}"#
    ));
    EngineErrorCode::Ok
}

fn cmd_diag_export(p: &serde_json::Value) -> EngineErrorCode {
    let anonymize = p["anonymize"].as_bool().unwrap_or(true);
    let history_count = CALL_HISTORY.lock().unwrap().len();
    let account_count = ACCOUNTS.lock().unwrap().len();
    push_event(format!(
        r#"{{"type":"DiagBundleReady","payload":{{"anonymize":{anonymize},"call_history_count":{history_count},"account_count":{account_count},"note":"TODO: real export"}}}}"#
    ));
    EngineErrorCode::Ok
}

/// Update TLS/SRTP security flags on an existing account.
/// `{"type":"AccountSetSecurity","payload":{"id":"...", "tls_enabled":true, "srtp_enabled":true}}`
fn cmd_account_set_security(p: &serde_json::Value) -> EngineErrorCode {
    let id = match p["id"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let mut accts = ACCOUNTS.lock().unwrap();
    match accts.iter_mut().find(|a| a.uuid == id) {
        None => EngineErrorCode::NotFound,
        Some(acct) => {
            if let Some(tls) = p["tls_enabled"].as_bool() {
                acct.tls_enabled = tls;
            }
            if let Some(srtp) = p["srtp_enabled"].as_bool() {
                acct.srtp_enabled = srtp;
            }
            let tls = acct.tls_enabled;
            let srtp = acct.srtp_enabled;
            drop(accts);
            // Use serde_json for safe JSON encoding of the account_id.
            let id_json = serde_json::to_string(&id).unwrap_or_default();
            push_event(format!(
                r#"{{"type":"AccountSecurityUpdated","payload":{{"account_id":{id_json},"tls_enabled":{tls},"srtp_enabled":{srtp}}}}}"#
            ));
            // TLS/SRTP changes take effect on the next AccountRegister call.
            // Re-registration with the updated settings is the user's responsibility.
            EngineErrorCode::Ok
        }
    }
}

/// Store a named credential in the in-memory credential store.
/// `{"type":"CredStore","payload":{"key":"my_key","value":"secret"}}`
/// Persisting to the OS keychain (Windows Credential Manager) is a future milestone.
fn cmd_cred_store(p: &serde_json::Value) -> EngineErrorCode {
    let key = match p["key"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let value = match p["value"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    CRED_STORE.lock().unwrap().insert(key.clone(), value);
    // Use serde_json for safe JSON encoding of the key.
    let key_json = serde_json::to_string(&key).unwrap_or_default();
    push_event(format!(
        r#"{{"type":"CredStored","payload":{{"key":{key_json}}}}}"#
    ));
    EngineErrorCode::Ok
}

/// Retrieve a named credential from the in-memory credential store.
/// `{"type":"CredRetrieve","payload":{"key":"my_key"}}`
/// Returns `EngineErrorCode::NotFound` if the key does not exist.
fn cmd_cred_retrieve(p: &serde_json::Value) -> EngineErrorCode {
    let key = match p["key"].as_str() {
        Some(s) => s.to_owned(),
        None => return EngineErrorCode::InvalidJson,
    };
    let store = CRED_STORE.lock().unwrap();
    match store.get(&key) {
        None => EngineErrorCode::NotFound,
        Some(value) => {
            // Use serde_json for correct JSON encoding of key and value.
            let key_json = serde_json::to_string(&key).unwrap_or_default();
            let value_json = serde_json::to_string(value).unwrap_or_default();
            push_event(format!(
                r#"{{"type":"CredRetrieved","payload":{{"key":{key_json},"value":{value_json}}}}}"#
            ));
            EngineErrorCode::Ok
        }
    }
}

/// Liveness / health-check ping.
/// `{"type":"EnginePing","payload":{}}` → event `{"type":"EnginePong","payload":{}}`
fn cmd_engine_ping(_p: &serde_json::Value) -> EngineErrorCode {
    push_event(r#"{"type":"EnginePong","payload":{}}"#.to_owned());
    EngineErrorCode::Ok
}

/// Set the active log level filter.
/// `{"type":"SetLogLevel","payload":{"level":"Debug"}}`
/// Valid levels: "Error", "Warn", "Info", "Debug".
/// Messages with level ≤ active filter are emitted as EngineLog events.
fn cmd_set_log_level(p: &serde_json::Value) -> EngineErrorCode {
    let level_str = match p["level"].as_str() {
        Some(s) => s,
        None => return EngineErrorCode::InvalidJson,
    };
    match LogLevel::from_str(level_str) {
        None => EngineErrorCode::InvalidJson,
        Some(level) => {
            ACTIVE_LOG_LEVEL.store(level as u8, Ordering::Relaxed);
            push_event(format!(
                r#"{{"type":"LogLevelSet","payload":{{"level":"{}"}}}}"#,
                level.as_str()
            ));
            EngineErrorCode::Ok
        }
    }
}

/// Return all buffered log entries as a `LogBufferResult` event.
/// `{"type":"GetLogBuffer","payload":{}}` → `{"type":"LogBufferResult","payload":{"entries":[...]}}`
fn cmd_get_log_buffer(_p: &serde_json::Value) -> EngineErrorCode {
    let buf = LOG_BUFFER.lock().unwrap();
    let mut items = String::new();
    for (i, e) in buf.iter().enumerate() {
        if i > 0 {
            items.push(',');
        }
        let msg_escaped = e
            .message
            .replace('\\', "\\\\")
            .replace('"', "\\\"")
            .replace('\n', "\\n")
            .replace('\r', "\\r");
        items.push_str(&format!(
            r#"{{"level":"{}","message":"{msg_escaped}","ts":{}}}"#,
            e.level.as_str(),
            e.ts
        ));
    }
    drop(buf);
    push_event(format!(
        r#"{{"type":"LogBufferResult","payload":{{"entries":[{items}]}}}}"#
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
/// Initialise pjsua with transports and register PJSIP callbacks.
#[no_mangle]
pub extern "C" fn engine_init(user_agent: *const c_char) -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if INITIALIZED.swap(true, Ordering::SeqCst) {
            log_engine(
                LogLevel::Warn,
                "engine_init called while already initialized",
            );
            return EngineErrorCode::AlreadyInitialized as i32;
        }

        let rc = unsafe {
            pd_init(
                user_agent,
                std::ptr::null(), // no global STUN; set per-account
                pjsip_on_reg_state,
                pjsip_on_incoming_call,
                pjsip_on_call_state,
                pjsip_on_call_media,
                pjsip_on_log,
                pjsip_on_sip_msg,
            )
        };
        if rc != 0 {
            INITIALIZED.store(false, Ordering::SeqCst);
            log_engine(
                LogLevel::Error,
                &format!("Engine init failed: pd_init returned {rc}"),
            );
            return EngineErrorCode::InternalError as i32;
        }
        push_event(r#"{"type":"EngineReady","payload":{}}"#.to_owned());
        log_engine(LogLevel::Info, "Engine initialized (PJSIP active)");

        // Start IPC API Server for external integrations (pd.exe, local scripts)
        api_server_start();

        EngineErrorCode::Ok as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Shutdown the engine, destroying pjsua if it was initialized.
#[no_mangle]
pub extern "C" fn engine_shutdown() -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.swap(false, Ordering::SeqCst) {
            log_engine(
                LogLevel::Warn,
                "engine_shutdown called while not initialized",
            );
            return EngineErrorCode::NotInitialized as i32;
        }
        log_engine(LogLevel::Info, "Engine shutting down");

        // Remove all PJSIP accounts to ensure clean unregistration
        let pj_acc_ids: Vec<i32> = PJSIP_ACC_MAP.lock().unwrap().keys().copied().collect();
        for pj_id in pj_acc_ids {
            unsafe { pd_acc_remove(pj_id) };
        }
        PJSIP_ACC_MAP.lock().unwrap().clear();
        PJSIP_CALL_MAP.lock().unwrap().clear();
        unsafe { pd_shutdown() };

        EngineErrorCode::Ok as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

fn api_server_start() {
    let _ = thread::Builder::new()
        .name("api-server".to_owned())
        .spawn(|| {
            let name = "PacketDial.API";
            // On Windows, LocalSocketListener::bind("name") creates \\.\pipe\name
            let listener = match LocalSocketListener::bind(name) {
                Ok(l) => l,
                Err(e) => {
                    log_engine(
                        LogLevel::Error,
                        &format!("API Server: Failed to bind {name}: {e}"),
                    );
                    return;
                }
            };
            log_engine(
                LogLevel::Info,
                "API Server: Listening on \\\\.\\pipe\\PacketDial.API",
            );

            for stream in listener.incoming().flatten() {
                thread::spawn(move || {
                    handle_api_client(stream);
                });
            }
        });
}

fn handle_api_client(stream: LocalSocketStream) {
    let _ = stream.set_nonblocking(true);
    let (tx, rx) = unbounded::<String>();

    // Register this client for events
    {
        CLIENT_SENDERS.lock().unwrap().push(tx);
    }

    let mut reader = BufReader::new(stream);
    let mut line = String::new();

    loop {
        // 1. Check for events from the DLL to broadcast to this client
        while let Ok(msg) = rx.try_recv() {
            let s = reader.get_mut();
            if s.write_all(msg.as_bytes()).is_err() || s.write_all(b"\n").is_err() {
                return;
            }
            let _ = s.flush();
        }

        // 2. Check for commands from the client to the DLL
        match reader.read_line(&mut line) {
            Ok(0) => break, // EOF
            Ok(_) => {
                if let Ok(v) = serde_json::from_str::<serde_json::Value>(&line) {
                    let cmd_type = v["type"].as_str().unwrap_or("");
                    let payload = v.get("payload").unwrap_or(&serde_json::Value::Null);
                    let rc = dispatch_command(cmd_type, payload);

                    let response = format!(
                        "{{\"type\":\"CommandResponse\",\"payload\":{{\"rc\":{}}}}}\n",
                        rc as i32
                    );
                    let s = reader.get_mut();
                    let _ = s.write_all(response.as_bytes());
                    let _ = s.flush();
                }
                line.clear();
            }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                // No command data yet, wait a bit to avoid high CPU usage
                thread::sleep(std::time::Duration::from_millis(50));
            }
            Err(_) => break, // Connection closed or error
        }
    }
}

/// Returns a pointer to a static, null-terminated UTF-8 string.
/// The pointer remains valid for the lifetime of the process.
#[no_mangle]
pub extern "C" fn engine_version() -> *const c_char {
    version_cstr().as_ptr()
}

// ---------------------------------------------------------------------------
// C ABI — event callback types & storage
// ---------------------------------------------------------------------------

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq)]
pub enum EngineEventId {
    EngineReady = 1,
    RegistrationStateChanged = 2,
    CallStateChanged = 3,
    MediaStatsUpdated = 4,
    AudioDeviceList = 5,
    AudioDevicesSet = 6,
    CallHistoryResult = 7,
    SipMessageCaptured = 8,
    DiagBundleReady = 9,
    AccountSecurityUpdated = 10,
    CredStored = 11,
    CredRetrieved = 12,
    EnginePong = 13,
    LogLevelSet = 14,
    LogBufferResult = 15,
    EngineLog = 16,
}

/// C callback: `void (*)(int event_id, const char* message)`
type EngineEventCallback = Option<extern "C" fn(event_id: i32, message: *const c_char)>;

static EVENT_CALLBACK: Lazy<Mutex<EngineEventCallback>> = Lazy::new(|| Mutex::new(None));

/// All active IPC client senders for event broadcasting.
static CLIENT_SENDERS: Lazy<Mutex<Vec<Sender<String>>>> = Lazy::new(|| Mutex::new(Vec::new()));

fn invoke_event_callback(event_id: EngineEventId, message: &str) {
    // IMPORTANT: The Dart side uses NativeCallable.listener which runs the
    // callback ASYNCHRONOUSLY on the Dart event loop.  This means the C
    // string pointer must remain valid after this function returns.
    //
    // We keep two recent CString allocations alive (double-buffer) so
    // the previous pointer is still valid while Dart processes it.
    use once_cell::sync::Lazy;
    use std::sync::Mutex;
    static PREV: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));
    static CURR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));

    if let Ok(g) = EVENT_CALLBACK.lock() {
        if let Some(cb) = *g {
            if let Ok(cs) = CString::new(message) {
                let ptr = cs.as_ptr();
                // Rotate: drop prev, move curr → prev, store new → curr
                {
                    let mut prev = PREV.lock().unwrap();
                    let mut curr = CURR.lock().unwrap();
                    *prev = curr.take();
                    *curr = Some(cs);
                }
                cb(event_id as i32, ptr);
            }
        }
    }
}
// ---------------------------------------------------------------------------
// C ABI — direct structured API (no JSON parsing needed)
// ---------------------------------------------------------------------------

/// Set a callback function that receives structured events.
///
/// The callback signature is: `void cb(int event_id, const char* json_data)`
///
/// Event IDs:
///   1 = EngineReady, 2 = RegistrationStateChanged, 3 = CallStateChanged,
///   4 = MediaStatsUpdated, 5 = AudioDeviceList, 6 = AudioDevicesSet,
///   7 = CallHistoryResult, 8 = SipMessageCaptured, 9 = DiagBundleReady,
///   10 = AccountSecurityUpdated, 11 = CredStored, 12 = CredRetrieved,
///   13 = EnginePong, 14 = LogLevelSet, 15 = LogBufferResult, 16 = EngineLog
///
/// The json_data parameter contains event-specific data as a JSON string.
/// Pass NULL to clear the callback.
///
/// # Safety
/// The callback must remain valid for the lifetime of the engine.
#[no_mangle]
pub extern "C" fn engine_set_event_callback(
    cb: Option<extern "C" fn(event_id: i32, message: *const c_char)>,
) {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if let Ok(mut g) = EVENT_CALLBACK.lock() {
            *g = cb;
        }
    }));
    // Panic in set_event_callback is non-critical; silently ignore.
    let _ = result;
}

/// Send a structured command to the engine as JSON.
///
/// `cmd_type` is the name of the command (e.g. "AccountUpsert").
/// `json_payload` is the command parameters as a JSON string.
///
/// Returns 0 (Ok) on success, or a non-zero error code.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn engine_send_command(cmd_type: *const c_char, json_payload: *const c_char) -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if cmd_type.is_null() || json_payload.is_null() {
            return EngineErrorCode::InvalidUtf8 as i32;
        }
        let cmd_s = match unsafe { CStr::from_ptr(cmd_type) }.to_str() {
            Ok(s) => s,
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };
        let payload_s = match unsafe { CStr::from_ptr(json_payload) }.to_str() {
            Ok(s) => s,
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };

        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        let payload_v: serde_json::Value = match serde_json::from_str(payload_s) {
            Ok(v) => v,
            Err(_) => return EngineErrorCode::InvalidJson as i32,
        };

        dispatch_command(cmd_s, &payload_v) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Register a SIP account with the engine.
///
/// This is a convenience wrapper around the JSON `AccountUpsert` +
/// `AccountRegister` commands.  All strings must be null-terminated UTF-8.
///
/// `account_id` is the user-provided identifier for the account (can be any string).
/// `user`, `pass`, and `domain` are the SIP credentials.
///
/// Returns 0 on success, non-zero on error.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn engine_register(
    account_id: *const c_char,
    user: *const c_char,
    pass: *const c_char,
    domain: *const c_char,
) -> i32 {
    if account_id.is_null() || user.is_null() || pass.is_null() || domain.is_null() {
        return EngineErrorCode::InvalidUtf8 as i32;
    }
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        let acct_id = match unsafe { CStr::from_ptr(account_id) }.to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };
        let user_s = match unsafe { CStr::from_ptr(user) }.to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };
        let pass_s = match unsafe { CStr::from_ptr(pass) }.to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };
        let domain_s = match unsafe { CStr::from_ptr(domain) }.to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };

        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        // Upsert account with user-provided account_id
        let upsert_json = serde_json::json!({
            "uuid": acct_id,
            "display_name": &user_s,
            "server": &domain_s,
            "username": &user_s,
            "password": &pass_s,
        });
        let rc = dispatch_command("AccountUpsert", &upsert_json);
        if rc != EngineErrorCode::Ok {
            return rc as i32;
        }

        // Register
        let reg_json = serde_json::json!({ "uuid": acct_id });
        dispatch_command("AccountRegister", &reg_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Make an outgoing call.
///
/// `account_id` is the account to use for the call (null-terminated UTF-8).
/// `number` is the destination SIP URI or phone number (null-terminated UTF-8).
///
/// Returns 0 on success, non-zero on error.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn engine_make_call(account_id: *const c_char, number: *const c_char) -> i32 {
    if account_id.is_null() || number.is_null() {
        return EngineErrorCode::InvalidUtf8 as i32;
    }
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        let account_id_s = match unsafe { CStr::from_ptr(account_id) }.to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };
        let number_s = match unsafe { CStr::from_ptr(number) }.to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };

        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        // Format as SIP URI if not already
        let uri = if number_s.starts_with("sip:") || number_s.starts_with("sips:") {
            number_s
        } else {
            // Extract domain from account_id (user@domain)
            let domain = match account_id_s.split('@').nth(1) {
                Some(d) => d,
                None => {
                    log_engine(
                        LogLevel::Error,
                        "Account has no domain for URI construction",
                    );
                    return EngineErrorCode::InternalError as i32;
                }
            };
            format!("sip:{number_s}@{domain}")
        };

        let call_json = serde_json::json!({
            "account_id": account_id_s,
            "uri": uri,
        });
        dispatch_command("CallStart", &call_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Hang up the current active call.
///
/// Returns 0 on success, non-zero on error.
#[no_mangle]
pub extern "C" fn engine_hangup() -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        // Find the first active (non-ended) call
        let call_id = {
            let calls = CALLS.lock().unwrap();
            calls
                .iter()
                .find(|c| c.state != CallState::Ended)
                .map(|c| c.id)
        };
        let call_id = match call_id {
            Some(id) => id,
            None => {
                return EngineErrorCode::NotFound as i32;
            }
        };

        let hangup_json = serde_json::json!({ "call_id": call_id });
        dispatch_command("CallHangup", &hangup_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Unregister a SIP account.
///
/// `account_id` must be a null-terminated UTF-8 string.
/// Returns 0 on success, non-zero on error.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn engine_unregister(account_id: *const c_char) -> i32 {
    if account_id.is_null() {
        return EngineErrorCode::InvalidUtf8 as i32;
    }
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        let id = match unsafe { CStr::from_ptr(account_id) }.to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };

        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        let unreg_json = serde_json::json!({ "uuid": id });
        dispatch_command("AccountUnregister", &unreg_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Answer an incoming call.
///
/// Answers the first ringing incoming call.
/// Returns 0 on success, non-zero on error.
#[no_mangle]
pub extern "C" fn engine_answer_call() -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        // Find the first ringing incoming call
        let call_id = {
            let calls = CALLS.lock().unwrap();
            calls
                .iter()
                .find(|c| {
                    c.state == CallState::Ringing && matches!(c.direction, CallDirection::Incoming)
                })
                .map(|c| c.id)
        };
        let call_id = match call_id {
            Some(id) => id,
            None => return EngineErrorCode::NotFound as i32,
        };

        let answer_json = serde_json::json!({ "call_id": call_id });
        dispatch_command("CallAnswer", &answer_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Toggle mute on the active call.
///
/// `muted` should be 1 to mute, 0 to unmute.
/// Returns 0 on success, non-zero on error.
#[no_mangle]
pub extern "C" fn engine_set_mute(muted: i32) -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        // Find the first active call
        let call_id = {
            let calls = CALLS.lock().unwrap();
            calls
                .iter()
                .find(|c| c.state != CallState::Ended)
                .map(|c| c.id)
        };
        let call_id = match call_id {
            Some(id) => id,
            None => return EngineErrorCode::NotFound as i32,
        };

        let mute_json = serde_json::json!({ "call_id": call_id, "muted": muted != 0 });
        dispatch_command("CallMute", &mute_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Toggle hold on the active call.
///
/// `on_hold` should be 1 to hold, 0 to resume.
/// Returns 0 on success, non-zero on error.
#[no_mangle]
pub extern "C" fn engine_set_hold(on_hold: i32) -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        // Find the first active call
        let call_id = {
            let calls = CALLS.lock().unwrap();
            calls
                .iter()
                .find(|c| c.state != CallState::Ended)
                .map(|c| c.id)
        };
        let call_id = match call_id {
            Some(id) => id,
            None => return EngineErrorCode::NotFound as i32,
        };

        let hold_json = serde_json::json!({ "call_id": call_id, "hold": on_hold != 0 });
        dispatch_command("CallHold", &hold_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Send DTMF digits on the active call.
///
/// `digits` must be a null-terminated UTF-8 string containing digits 0-9, *, #, A-D.
/// Returns 0 on success, non-zero on error.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn engine_send_dtmf(digits: *const c_char) -> i32 {
    if digits.is_null() {
        return EngineErrorCode::InvalidUtf8 as i32;
    }
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        let digits_s = match unsafe { CStr::from_ptr(digits) }.to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };

        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        // Find the first active call
        let call_id = {
            let calls = CALLS.lock().unwrap();
            calls
                .iter()
                .find(|c| c.state != CallState::Ended)
                .map(|c| c.id)
        };
        let call_id = match call_id {
            Some(id) => id,
            None => return EngineErrorCode::NotFound as i32,
        };

        let dtmf_json = serde_json::json!({ "call_id": call_id, "digits": digits_s });
        dispatch_command("CallSendDtmf", &dtmf_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Request audio device list.
///
/// This will trigger an AudioDeviceList event via the callback.
/// Returns 0 on success, non-zero on error.
#[no_mangle]
pub extern "C" fn engine_list_audio_devices() -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        let empty = serde_json::json!({});
        dispatch_command("AudioListDevices", &empty) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Set active audio devices.
///
/// `input_id` and `output_id` are device IDs from the AudioDeviceList event.
/// Returns 0 on success, non-zero on error.
#[no_mangle]
pub extern "C" fn engine_set_audio_devices(input_id: i32, output_id: i32) -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        let devices_json = serde_json::json!({ "input_id": input_id, "output_id": output_id });
        dispatch_command("AudioSetDevices", &devices_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Request call history.
///
/// This will trigger a CallHistoryResult event via the callback.
/// Returns 0 on success, non-zero on error.
#[no_mangle]
pub extern "C" fn engine_query_call_history() -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        let empty = serde_json::json!({});
        dispatch_command("CallHistoryQuery", &empty) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Set the active log level filter.
///
/// `level` must be one of: "Error", "Warn", "Info", "Debug".
/// Returns 0 on success, non-zero on error.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn engine_set_log_level(level: *const c_char) -> i32 {
    if level.is_null() {
        return EngineErrorCode::InvalidUtf8 as i32;
    }
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        let level_s = match unsafe { CStr::from_ptr(level) }.to_str() {
            Ok(s) => s,
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        };

        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        let level_json = serde_json::json!({ "level": level_s });
        dispatch_command("SetLogLevel", &level_json) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Request all buffered log entries.
///
/// This will trigger a LogBufferResult event via the callback.
/// Returns 0 on success, non-zero on error.
#[no_mangle]
pub extern "C" fn engine_get_log_buffer() -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }

        let empty = serde_json::json!({});
        dispatch_command("GetLogBuffer", &empty) as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Serialize test execution so that global state does not leak between tests.
    static TEST_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

    fn reset() {
        INITIALIZED.store(false, Ordering::SeqCst);
        // Use unwrap_or_else to recover from poisoned mutexes caused by prior test panics
        ACCOUNTS.lock().unwrap_or_else(|e| e.into_inner()).clear();
        CALLS.lock().unwrap_or_else(|e| e.into_inner()).clear();
        CALL_HISTORY
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clear();
        MEDIA_STATS
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clear();
        CRED_STORE.lock().unwrap_or_else(|e| e.into_inner()).clear();
        LOG_BUFFER.lock().unwrap_or_else(|e| e.into_inner()).clear();
        ACTIVE_LOG_LEVEL.store(LogLevel::Info as u8, Ordering::Relaxed);
        if let Ok(mut g) = EVENT_CALLBACK.lock() {
            *g = None;
        }
        SELECTED_INPUT.store(0, Ordering::Relaxed);
        SELECTED_OUTPUT.store(1, Ordering::Relaxed);
        {
            PJSIP_ACC_MAP
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .clear();
            PJSIP_CALL_MAP
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .clear();
        }
    }

    // NOTE: Most tests have been temporarily removed during migration to callback-based
    // C ABI. Tests will be rewritten to use structured C functions and event callbacks.

    #[test]
    fn init_shutdown_ok() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        assert_eq!(engine_init(std::ptr::null()), EngineErrorCode::Ok as i32);
        assert_eq!(engine_shutdown(), EngineErrorCode::Ok as i32);
    }

    #[test]
    fn init_twice() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        assert_eq!(engine_init(std::ptr::null()), EngineErrorCode::Ok as i32);
        assert_eq!(
            engine_init(std::ptr::null()),
            EngineErrorCode::AlreadyInitialized as i32
        );
        assert_eq!(engine_shutdown(), EngineErrorCode::Ok as i32);
    }
}

use once_cell::sync::Lazy;
use once_cell::sync::OnceCell;
use std::collections::{HashMap, VecDeque};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::AssertUnwindSafe;
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU8, Ordering};
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

static INITIALIZED: AtomicBool = AtomicBool::new(false);
static VERSION: OnceCell<CString> = OnceCell::new();
static NEXT_CALL_ID: AtomicU32 = AtomicU32::new(1);

static EVENT_QUEUE: Lazy<Mutex<VecDeque<String>>> = Lazy::new(|| Mutex::new(VecDeque::new()));
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
/// TODO: persist via Windows Credential Manager (wincred) in a future milestone.
static CRED_STORE: Lazy<Mutex<HashMap<String, String>>> = Lazy::new(|| Mutex::new(HashMap::new()));

/// Active log level filter. Messages with level ≤ this value are emitted and
/// buffered. Default: Info (2).  Levels: Error=0, Warn=1, Info=2, Debug=3.
static ACTIVE_LOG_LEVEL: AtomicU8 = AtomicU8::new(LogLevel::Info as u8);

/// Ring-buffer of recent log entries (capped at LOG_BUFFER_MAX).
static LOG_BUFFER: Lazy<Mutex<VecDeque<LogEntry>>> = Lazy::new(|| Mutex::new(VecDeque::new()));

const LOG_BUFFER_MAX: usize = 200;

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
    id: String,
    display_name: String,
    server: String,
    username: String,
    password: String,
    transport: String,
    stun_server: String,
    turn_server: String,
    /// Use TLS transport (SIP over TLS / SIPS).
    tls_enabled: bool,
    /// Require SRTP for media encryption.
    srtp_enabled: bool,
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
    started_at: u64,
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
        existing.transport = p["transport"].as_str().unwrap_or("udp").to_owned();
        existing.stun_server = p["stun_server"].as_str().unwrap_or("").to_owned();
        existing.turn_server = p["turn_server"].as_str().unwrap_or("").to_owned();
        existing.tls_enabled = p["tls_enabled"].as_bool().unwrap_or(existing.tls_enabled);
        existing.srtp_enabled = p["srtp_enabled"].as_bool().unwrap_or(existing.srtp_enabled);
    } else {
        let acct = Account {
            id: id.clone(),
            display_name: p["display_name"].as_str().unwrap_or("").to_owned(),
            server: p["server"].as_str().unwrap_or("").to_owned(),
            username: p["username"].as_str().unwrap_or("").to_owned(),
            password: p["password"].as_str().unwrap_or("").to_owned(),
            transport: p["transport"].as_str().unwrap_or("udp").to_owned(),
            stun_server: p["stun_server"].as_str().unwrap_or("").to_owned(),
            turn_server: p["turn_server"].as_str().unwrap_or("").to_owned(),
            tls_enabled: p["tls_enabled"].as_bool().unwrap_or(false),
            srtp_enabled: p["srtp_enabled"].as_bool().unwrap_or(false),
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
        None => {
            log_engine(
                LogLevel::Error,
                &format!("AccountRegister: account '{id}' not found"),
            );
            EngineErrorCode::NotFound
        }
        Some(acct) => {
            acct.reg_state = RegistrationState::Registering;
            drop(accts);
            push_reg_state(&id, &RegistrationState::Registering);
            log_engine(
                LogLevel::Debug,
                &format!("Account '{id}' registering (stub)"),
            );
            // TODO: trigger real PJSIP registration here.
            // Stub: transition immediately to Registered.
            let mut accts2 = ACCOUNTS.lock().unwrap();
            if let Some(a) = accts2.iter_mut().find(|a| a.id == id) {
                a.reg_state = RegistrationState::Registered;
            }
            drop(accts2);
            push_reg_state(&id, &RegistrationState::Registered);
            log_engine(
                LogLevel::Debug,
                &format!("Account '{id}' registered (stub)"),
            );
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
    log_engine(
        LogLevel::Debug,
        &format!("CallStart: call_id={call_id} uri={uri} account={account_id}"),
    );
    let call = Call {
        id: call_id,
        account_id,
        uri,
        direction: CallDirection::Outgoing,
        state: CallState::Ringing,
        muted: false,
        on_hold: false,
        started_at: now_secs(),
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
            let ended_at = now_secs();
            let duration = ended_at.saturating_sub(call.started_at);
            let entry = CallHistoryEntry {
                call_id: call.id,
                account_id: call.account_id.clone(),
                uri: call.uri.clone(),
                direction: call.direction.variant_name().to_owned(),
                started_at: call.started_at,
                ended_at,
                duration_secs: duration,
                end_state: "Ended".to_owned(),
            };
            CALL_HISTORY.lock().unwrap().push(entry);
            // Remove media stats for this call
            MEDIA_STATS.lock().unwrap().remove(&call_id);
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
    SELECTED_INPUT.store(input_id, Ordering::Relaxed);
    SELECTED_OUTPUT.store(output_id, Ordering::Relaxed);
    // TODO: apply to PJSIP audio device selection here.
    push_event(format!(
        r#"{{"type":"AudioDevicesSet","payload":{{"input_id":{input_id},"output_id":{output_id}}}}}"#
    ));
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
    match accts.iter_mut().find(|a| a.id == id) {
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
            // TODO: apply to PJSIP transport and SRTP policy here.
            EngineErrorCode::Ok
        }
    }
}

/// Store a named credential in the in-memory credential store.
/// `{"type":"CredStore","payload":{"key":"my_key","value":"secret"}}`
/// TODO: persist via Windows Credential Manager (wincred) in M7.
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
/// In future milestones, this will initialize PJSIP and related subsystems.
#[no_mangle]
pub extern "C" fn engine_init() -> i32 {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if INITIALIZED.swap(true, Ordering::SeqCst) {
            log_engine(
                LogLevel::Warn,
                "engine_init called while already initialized",
            );
            return EngineErrorCode::AlreadyInitialized as i32;
        }
        // TODO: initialize PJSIP here (pj_init, pjsua_create, etc.)
        push_event(r#"{"type":"EngineReady","payload":{}}"#.to_owned());
        log_engine(
            LogLevel::Info,
            "Engine initialized (stub — PJSIP not yet linked)",
        );
        EngineErrorCode::Ok as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Shutdown the engine.
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
        // TODO: shutdown PJSIP here (pjsua_destroy, etc.)
        log_engine(LogLevel::Info, "Engine shutting down");
        if let Ok(mut q) = EVENT_QUEUE.lock() {
            q.clear();
        }
        EngineErrorCode::Ok as i32
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
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
    if cmd_json.is_null() {
        return EngineErrorCode::InvalidJson as i32;
    }
    // Extract the string before entering catch_unwind (raw pointer ≠ UnwindSafe).
    let s_owned = unsafe {
        match CStr::from_ptr(cmd_json).to_str() {
            Ok(s) => s.to_owned(),
            Err(_) => return EngineErrorCode::InvalidUtf8 as i32,
        }
    };
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if !INITIALIZED.load(Ordering::SeqCst) {
            return EngineErrorCode::NotInitialized as i32;
        }
        let v: serde_json::Value = match serde_json::from_str(&s_owned) {
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
    }));
    result.unwrap_or(EngineErrorCode::InternalError as i32)
}

/// Poll for the next queued event from the engine.
///
/// Returns a heap-allocated null-terminated UTF-8 JSON string, or null if the
/// queue is empty.  **The caller must free the returned pointer with
/// `engine_free_string`.**
#[no_mangle]
pub extern "C" fn engine_poll_event() -> *mut c_char {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
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
    }));
    result.unwrap_or(std::ptr::null_mut())
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

    /// Serialize test execution so that global state does not leak between tests.
    static TEST_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

    fn reset() {
        INITIALIZED.store(false, Ordering::SeqCst);
        // Use unwrap_or_else to recover from poisoned mutexes caused by prior test panics
        EVENT_QUEUE
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clear();
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
        SELECTED_INPUT.store(0, Ordering::Relaxed);
        SELECTED_OUTPUT.store(1, Ordering::Relaxed);
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

    // --- original tests (unchanged) -----------------------------------------

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
        assert_eq!(send("not json"), EngineErrorCode::InvalidJson as i32);
        engine_shutdown();
    }

    #[test]
    fn account_register_flow() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(
            send(
                r#"{"type":"AccountUpsert","payload":{"id":"acc1","display_name":"Test","server":"sip.example.com","username":"user","password":"pass"}}"#
            ),
            0
        );
        let ev = next_event();
        assert!(ev.contains("Unregistered"), "got: {ev}");

        assert_eq!(
            send(r#"{"type":"AccountRegister","payload":{"id":"acc1"}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("Registering"), "got: {ev}");
        let ev = next_event();
        assert!(ev.contains("Registered"), "got: {ev}");

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

        assert_eq!(
            send(
                r#"{"type":"CallStart","payload":{"account_id":"acc1","uri":"sip:bob@example.com"}}"#
            ),
            0
        );
        let ev = next_event();
        assert!(ev.contains("Ringing"), "got: {ev}");

        let v: serde_json::Value = serde_json::from_str(&ev).unwrap();
        let call_id = v["payload"]["call_id"].as_u64().unwrap();

        let cmd = format!(r#"{{"type":"CallAnswer","payload":{{"call_id":{call_id}}}}}"#);
        assert_eq!(send(&cmd), 0);
        let ev = next_event();
        assert!(ev.contains("InCall"), "got: {ev}");

        let cmd = format!(r#"{{"type":"CallHold","payload":{{"call_id":{call_id},"hold":true}}}}"#);
        assert_eq!(send(&cmd), 0);
        let ev = next_event();
        assert!(ev.contains("OnHold"), "got: {ev}");

        let cmd =
            format!(r#"{{"type":"CallMute","payload":{{"call_id":{call_id},"muted":true}}}}"#);
        assert_eq!(send(&cmd), 0);
        let ev = next_event();
        assert!(ev.contains("OnHold"), "got: {ev}"); // state unchanged, muted=true

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

    // --- new M2/M3 tests ----------------------------------------------------

    #[test]
    fn account_upsert_with_transport() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(
            send(
                r#"{"type":"AccountUpsert","payload":{"id":"acc2","display_name":"T","server":"sip.test","username":"u","password":"p","transport":"tcp","stun_server":"stun.test:3478","turn_server":""}}"#
            ),
            0
        );
        let ev = next_event();
        assert!(ev.contains("Unregistered"), "got: {ev}");
        let accts = ACCOUNTS.lock().unwrap();
        let a = accts.iter().find(|a| a.id == "acc2").unwrap();
        assert_eq!(a.transport, "tcp");
        assert_eq!(a.stun_server, "stun.test:3478");

        engine_shutdown();
    }

    #[test]
    fn call_history_recorded() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(
            send(
                r#"{"type":"CallStart","payload":{"account_id":"acc1","uri":"sip:alice@example.com"}}"#
            ),
            0
        );
        let ev = next_event();
        let v: serde_json::Value = serde_json::from_str(&ev).unwrap();
        let call_id = v["payload"]["call_id"].as_u64().unwrap();

        let cmd = format!(r#"{{"type":"CallHangup","payload":{{"call_id":{call_id}}}}}"#);
        assert_eq!(send(&cmd), 0);
        drain_events();

        // Query history
        assert_eq!(send(r#"{"type":"CallHistoryQuery","payload":{}}"#), 0);
        let ev = next_event();
        assert!(ev.contains("CallHistoryResult"), "got: {ev}");
        assert!(ev.contains("sip:alice@example.com"), "got: {ev}");
        assert!(ev.contains("Outgoing"), "got: {ev}");

        engine_shutdown();
    }

    #[test]
    fn media_stats_update() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(
            send(
                r#"{"type":"MediaStatsUpdate","payload":{"call_id":42,"jitter_ms":12.5,"packet_loss_pct":0.5,"codec":"OPUS","bitrate_kbps":32}}"#
            ),
            0
        );
        let ev = next_event();
        assert!(ev.contains("MediaStatsUpdated"), "got: {ev}");
        assert!(ev.contains("OPUS"), "got: {ev}");
        assert!(ev.contains("12.5"), "got: {ev}");
        let stats = MEDIA_STATS.lock().unwrap();
        let s = stats.get(&42).unwrap();
        assert_eq!(s.codec, "OPUS");
        assert!((s.jitter_ms - 12.5).abs() < 0.01);

        engine_shutdown();
    }

    #[test]
    fn audio_list_and_set_devices() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(send(r#"{"type":"AudioListDevices","payload":{}}"#), 0);
        let ev = next_event();
        assert!(ev.contains("AudioDeviceList"), "got: {ev}");
        assert!(ev.contains("Default Input"), "got: {ev}");

        assert_eq!(
            send(r#"{"type":"AudioSetDevices","payload":{"input_id":0,"output_id":1}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("AudioDevicesSet"), "got: {ev}");
        assert_eq!(SELECTED_INPUT.load(Ordering::Relaxed), 0);
        assert_eq!(SELECTED_OUTPUT.load(Ordering::Relaxed), 1);

        // Invalid device ids
        assert_eq!(
            send(r#"{"type":"AudioSetDevices","payload":{"input_id":99,"output_id":1}}"#),
            EngineErrorCode::NotFound as i32
        );

        engine_shutdown();
    }

    #[test]
    fn sip_capture_message() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(
            send(
                r#"{"type":"SipCaptureMessage","payload":{"direction":"recv","raw":"INVITE sip:bob@example.com SIP/2.0\nAuthorization: Digest username=\"alice\", response=\"abc123\"\n"}}"#
            ),
            0
        );
        let ev = next_event();
        assert!(ev.contains("SipMessageCaptured"), "got: {ev}");
        assert!(
            ev.contains("MASKED"),
            "Authorization should be masked; got: {ev}"
        );

        engine_shutdown();
    }

    #[test]
    fn log_masking() {
        let input = "INVITE sip:user:secret@sip.example.com SIP/2.0\nAuthorization: Digest username=\"alice\", response=\"abc\"\nContact: sip:alice@192.168.1.1\n";
        let masked = mask_sip_log(input);
        assert!(!masked.contains("secret"), "password leaked: {masked}");
        assert!(!masked.contains("Digest"), "auth details leaked: {masked}");
        assert!(
            masked.contains("alice@192.168.1.1"),
            "non-sensitive data missing: {masked}"
        );
        assert!(masked.contains("MASKED"), "mask marker missing: {masked}");
    }

    // --- M6: Hardening & TLS tests ------------------------------------------

    #[test]
    fn account_tls_srtp_flags() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        // Create account with TLS + SRTP enabled
        assert_eq!(
            send(
                r#"{"type":"AccountUpsert","payload":{"id":"tls1","display_name":"TLS","server":"sips.example.com","username":"u","password":"p","tls_enabled":true,"srtp_enabled":true}}"#
            ),
            0
        );
        drain_events();
        {
            let accts = ACCOUNTS.lock().unwrap();
            let a = accts.iter().find(|a| a.id == "tls1").unwrap();
            assert!(a.tls_enabled, "tls_enabled should be true");
            assert!(a.srtp_enabled, "srtp_enabled should be true");
        }

        // Update via AccountSetSecurity
        assert_eq!(
            send(
                r#"{"type":"AccountSetSecurity","payload":{"id":"tls1","tls_enabled":false,"srtp_enabled":false}}"#
            ),
            0
        );
        let ev = next_event();
        assert!(ev.contains("AccountSecurityUpdated"), "got: {ev}");
        assert!(ev.contains("\"tls_enabled\":false"), "got: {ev}");
        {
            let accts = ACCOUNTS.lock().unwrap();
            let a = accts.iter().find(|a| a.id == "tls1").unwrap();
            assert!(!a.tls_enabled);
            assert!(!a.srtp_enabled);
        }

        engine_shutdown();
    }

    #[test]
    fn account_set_security_not_found() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();
        assert_eq!(
            send(r#"{"type":"AccountSetSecurity","payload":{"id":"ghost","tls_enabled":true}}"#),
            EngineErrorCode::NotFound as i32
        );
        engine_shutdown();
    }

    #[test]
    fn cred_store_and_retrieve() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(
            send(r#"{"type":"CredStore","payload":{"key":"acc1_pass","value":"s3cr3t"}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("CredStored"), "got: {ev}");
        assert!(ev.contains("acc1_pass"), "got: {ev}");

        assert_eq!(
            send(r#"{"type":"CredRetrieve","payload":{"key":"acc1_pass"}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("CredRetrieved"), "got: {ev}");
        assert!(ev.contains("s3cr3t"), "got: {ev}");

        engine_shutdown();
    }

    #[test]
    fn cred_retrieve_not_found() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();
        assert_eq!(
            send(r#"{"type":"CredRetrieve","payload":{"key":"missing_key"}}"#),
            EngineErrorCode::NotFound as i32
        );
        engine_shutdown();
    }

    #[test]
    fn engine_ping_pong() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(send(r#"{"type":"EnginePing","payload":{}}"#), 0);
        let ev = next_event();
        assert!(ev.contains("EnginePong"), "got: {ev}");

        engine_shutdown();
    }

    // --- M7: Logging system tests -------------------------------------------

    #[test]
    fn set_log_level_and_engine_log_event() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        // Set level to Debug — all log entries should emit events
        assert_eq!(
            send(r#"{"type":"SetLogLevel","payload":{"level":"Debug"}}"#),
            0
        );
        let ev = next_event();
        assert!(ev.contains("LogLevelSet"), "got: {ev}");
        assert!(ev.contains("\"level\":\"Debug\""), "got: {ev}");

        // Emit an Info message — should appear as EngineLog event (Debug >= Info)
        log_engine(LogLevel::Info, "test info message");
        let ev = next_event();
        assert!(ev.contains("EngineLog"), "got: {ev}");
        assert!(ev.contains("Info"), "got: {ev}");
        assert!(ev.contains("test info message"), "got: {ev}");

        engine_shutdown();
    }

    #[test]
    fn log_level_filter_suppresses_lower_severity() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        // Set level to Error — only Error events should pass through
        assert_eq!(
            send(r#"{"type":"SetLogLevel","payload":{"level":"Error"}}"#),
            0
        );
        drain_events();

        // A Debug message should be buffered but NOT emit an event
        log_engine(LogLevel::Debug, "debug noise");
        // A Warn message should be buffered but NOT emit an event (Warn > Error)
        log_engine(LogLevel::Warn, "warn noise");
        // An Error message should emit an event
        log_engine(LogLevel::Error, "critical failure");

        // Only one EngineLog event (Error level)
        let ev = next_event();
        assert!(ev.contains("EngineLog"), "got: {ev}");
        assert!(ev.contains("\"level\":\"Error\""), "got: {ev}");
        assert!(ev.contains("critical failure"), "got: {ev}");

        // No more events
        let ptr = engine_poll_event();
        assert!(ptr.is_null(), "unexpected extra event in queue");

        // But both entries should still be in the buffer
        assert_eq!(send(r#"{"type":"GetLogBuffer","payload":{}}"#), 0);
        let ev = next_event();
        assert!(ev.contains("LogBufferResult"), "got: {ev}");
        assert!(ev.contains("debug noise"), "got: {ev}");
        assert!(ev.contains("warn noise"), "got: {ev}");
        assert!(ev.contains("critical failure"), "got: {ev}");

        engine_shutdown();
    }

    #[test]
    fn get_log_buffer_returns_engine_init_log() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        // engine_init logs an Info message; it should be in the buffer
        assert_eq!(send(r#"{"type":"GetLogBuffer","payload":{}}"#), 0);
        let ev = next_event();
        assert!(ev.contains("LogBufferResult"), "got: {ev}");
        assert!(ev.contains("Engine initialized"), "got: {ev}");

        engine_shutdown();
    }

    #[test]
    fn set_log_level_invalid_returns_error() {
        let _guard = TEST_LOCK.lock().unwrap();
        reset();
        engine_init();
        drain_events();

        assert_eq!(
            send(r#"{"type":"SetLogLevel","payload":{"level":"Verbose"}}"#),
            EngineErrorCode::InvalidJson as i32
        );

        engine_shutdown();
    }
}

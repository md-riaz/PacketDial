# Changelog

All notable changes to PacketDial are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased] — M2/M3 Calling & Diagnostics

### Added

#### Rust core (`core_rust`)
- `MediaStatsUpdated` event + `MediaStatsUpdate` command: per-call jitter,
  packet loss, codec, and bitrate tracking
- `AudioListDevices` command → `AudioDeviceList` event: enumerate and expose
  stub input/output devices; auto-emitted on `EngineReady`
- `AudioSetDevices` command → `AudioDevicesSet` event: select active
  input/output device pair
- `CallHistoryResult` event + `CallHistoryQuery` command: store and retrieve
  ended-call records (call_id, URI, direction, duration, timestamps)
- `SipMessageCaptured` event + `SipCaptureMessage` command: capture raw SIP
  messages with automatic credential masking
- `DiagExportBundle` payload now includes `call_history_count` and
  `account_count`
- `mask_sip_log(input)` utility: redacts `Authorization`/`Proxy-Authorization`
  header values and `sip:user:password@host` URI passwords
- `Account` struct extended with `transport`, `stun_server`, `turn_server`
- `AccountUpsert` accepts `transport` (udp/tcp), `stun_server`, `turn_server`
- `Call` struct extended with `started_at` timestamp; duration computed on hangup
- 6 new unit tests (15 total): transport fields, call history, media stats,
  audio devices, SIP capture, log masking

#### Flutter app (`app_flutter`)
- `lib/models/media_stats.dart` — `MediaStats` model
- `lib/models/call_history.dart` — `CallHistoryEntry` model with `durationLabel`
- `lib/models/audio_device.dart` — `AudioDevice` model
- `lib/models/account.dart` — extended with `transport`, `stunServer`,
  `turnServer`
- `lib/core/engine_channel.dart` — handles `MediaStatsUpdated`,
  `AudioDeviceList`, `AudioDevicesSet`, `CallHistoryResult`; drains all
  queued events per poll tick; auto-requests audio device list on startup
- `lib/screens/accounts_screen.dart` — transport selector (UDP/TCP) and
  STUN/TURN server fields in account add/edit dialog
- `lib/screens/active_call_screen.dart` — media quality stats card
  (codec, bitrate, jitter, packet loss) + audio device picker sheet
- `lib/screens/history_screen.dart` — new: call history list with direction
  icon, URI, account, duration, and end-state
- `lib/main.dart` — 5-tab nav (added History between Call and Diagnostics)

#### Docs
- `docs/FFI_API.md` — updated command/event tables with all M2/M3 additions

---

## [Unreleased] — M1 Foundation

### Added

#### Rust core (`core_rust`)
- `engine_send_command(cmd_json)` — JSON command ingress (C ABI)
- `engine_poll_event()` — JSON event egress (C ABI, caller-freed string)
- `engine_free_string(ptr)` — companion deallocation function
- Registration state machine: `Unregistered → Registering → Registered → Failed`
  - Commands: `AccountUpsert`, `AccountRegister`, `AccountUnregister`
  - Events: `EngineReady`, `RegistrationStateChanged`
- Call state machine: `Ringing → InCall ↔ OnHold → Ended`
  - Commands: `CallStart`, `CallAnswer`, `CallHangup`, `CallMute`, `CallHold`
  - Event: `CallStateChanged`
- Diagnostic bundle stub: `DiagExportBundle` → `DiagBundleReady`
- 9 unit tests covering init/shutdown, command dispatch, registration flow,
  call flow (answer → hold → mute → hangup), error paths
- `serde` / `serde_json` dependencies for JSON parsing

#### Flutter app (`app_flutter`)
- `lib/ffi/engine.dart` — FFI bindings for `engine_send_command`,
  `engine_poll_event`, `engine_free_string`; UTF-8 C-string helpers
- `lib/core/engine_channel.dart` — `EngineChannel` singleton: 50 ms poll
  timer, `StreamController` broadcast, in-memory state for accounts and
  active call
- `lib/models/account.dart` — `Account` / `RegistrationState` models
- `lib/models/call.dart` — `ActiveCall` / `CallState` / `CallDirection` models
- `lib/screens/accounts_screen.dart` — list accounts, add/edit dialog,
  register / unregister actions
- `lib/screens/dialer_screen.dart` — numeric keypad, SIP URI field,
  account selector, Call button
- `lib/screens/active_call_screen.dart` — in-call controls (mute, hold,
  hang-up)
- `lib/screens/diagnostics_screen.dart` — live event log, copy-all,
  clear, Export Debug Bundle button
- `lib/main.dart` rewritten as a `NavigationBar` shell (Accounts / Dialer /
  Call / Diagnostics) with `EngineChannel` wiring
- Added `ffi: ^2.1.0` dependency for `calloc` allocator

#### CI
- `.github/workflows/rust-ci.yml` — Linux CI job running
  `cargo test` + `cargo clippy -D warnings` on every push/PR

#### Docs
- `docs/FFI_API.md` updated with full command/event tables and error codes

### Changed
- `docs/FFI_API.md` — replaced stub with full command/event surface

---

## [0.1.0] — 2026-03-02 — Initial scaffold

- Monorepo structure: `engine_pjsip/`, `core_rust/`, `app_flutter/`,
  `scripts/`, `docs/`
- Rust stub DLL (`engine_init`, `engine_shutdown`, `engine_version`)
- Flutter Windows app loading the DLL and displaying engine status
- PowerShell build scripts for PJSIP, Rust core, and Flutter
- Windows CI scaffold (`windows-ci.yml`)
- Architecture, spec, security, test-plan, and UX-flow documentation

# Changelog

All notable changes to PacketDial are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

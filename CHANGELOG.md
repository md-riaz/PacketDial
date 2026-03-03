# Changelog

All notable changes to PacketDial are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased] — M7 PJSIP Integration

### Changed

#### PJSIP source delivery (vendored directly in repo — no download or submodule)
- **`engine_pjsip/pjproject/`** — pjproject **2.14.1** source committed directly into
  the repository as plain files (3 075 files, ~64 MB uncompressed).  A plain
  `git clone https://github.com/md-riaz/PacketDial` is all that is needed; no
  `--recurse-submodules`, no runtime download, no internet access required at build time.
- **`.gitignore`** — `engine_pjsip/pjproject/` is no longer ignored; only the compiled
  output (`engine_pjsip/build/`) remains ignored.
- **`engine_pjsip/README.md`** — updated to document vendored source.
- **`scripts/build_pjsip.ps1`** — removed all fetch/submodule logic; now verifies the
  vendored source directory exists and proceeds directly to the msbuild step.
- **`scripts/fetch_pjsip.ps1`** — deleted (no longer needed).
- **`scripts/setup_windows.ps1`** — PJSIP step calls `build_pjsip.ps1` directly with
  stamp-file idempotency; submodule initialisation logic removed.
- **CI workflows** (`windows-ci.yml`, `release.yml`) — removed `submodules: recursive`
  from checkout (no submodules exist); PJSIP build cache key hashes
  `engine_pjsip/pjproject_config_site.h` so it invalidates when the config changes.
- **`docs/build_windows.md`**, **`docs/windows_setup_guide.md`** — clone command
  is plain `git clone` (no `--recurse-submodules`); PJSIP step is just
  `.\scripts\build_pjsip.ps1`.

### Added

#### PJSIP Build Infrastructure
- **`scripts/build_pjsip.ps1`** (rewritten) — verifies pjproject submodule, locates
  MSBuild via `vswhere`, builds `pjproject-vs14.sln` (Release/x64), collects all
  `*Release*.lib` and include directories into `engine_pjsip/build/out/`.
- **`engine_pjsip/pjproject_config_site.h`** (committed) — PacketDial-specific pjproject
  compile-time configuration: IPv6 enabled, WASAPI audio, video disabled, TLS disabled
  for this milestone, conservative account/call limits.


#### Rust core (`core_rust/`)
- **`build.rs`** (rewritten) — auto-detects built PJSIP output at
  `engine_pjsip/build/out/` (or via `PJSIP_LIB_DIR` / `PJSIP_INCLUDE_DIR` env vars),
  links all `.lib` files from that directory, and adds required Windows system libraries
  (`ws2_32`, `ole32`, `uuid`, `winmm`, `Avrt`).  Builds an optional C shim when
  `src/shim/pjsip_shim.c` is present (M7 implementation hook).
  Gracefully falls back to stub build when PJSIP is not present.
- **Structured logging system** (`LogLevel`, `LogEntry`, `LOG_BUFFER`, `ACTIVE_LOG_LEVEL`):
  - `LogLevel` enum: `Error=0`, `Warn=1`, `Info=2`, `Debug=3`.
  - `LOG_BUFFER` ring buffer (max 200 entries) — always populated regardless of active level.
  - `ACTIVE_LOG_LEVEL` atomic — defaults to `Info`; controls which entries emit events.
  - `log_engine(level, msg)` internal helper used throughout the engine.
- **`SetLogLevel` command** — `{"type":"SetLogLevel","payload":{"level":"Debug"}}`.
  Emits `LogLevelSet` event.
- **`GetLogBuffer` command** — returns all buffered entries as `LogBufferResult` event.
- **`EngineLog` event** — `{"type":"EngineLog","payload":{"level":"…","message":"…","ts":…}}`.
  Emitted for entries at or above the active log level.
- Engine state transitions now call `log_engine`:
  - `engine_init` → `Info` after `EngineReady`, `Warn` on double-init.
  - `engine_shutdown` → `Info` on graceful shutdown, `Warn` on not-initialized.
  - `AccountRegister` → `Error` on not-found, `Debug` on state transitions.
  - `CallStart` → `Debug` with call_id/uri/account details.
- **4 new unit tests** (24 total): `set_log_level_and_engine_log_event`,
  `log_level_filter_suppresses_lower_severity`, `get_log_buffer_returns_engine_init_log`,
  `set_log_level_invalid_returns_error`.

#### Flutter app
- **`lib/models/log_entry.dart`** — `LogLevel` enum + `LogEntry` model (`level`, `message`, `ts`).
- **`EngineChannel`** — handles `EngineLog` and `LogBufferResult` events; maintains
  `logBuffer` list (capped at 500 entries); exposes `setLogLevel(level)` and
  `getLogBuffer()` helpers.
- **`DiagnosticsScreen`** — redesigned as a two-tab screen:
  - *Events* tab: raw JSON event log (existing behaviour, unchanged).
  - *Logs* tab: structured log entries with:
    - **Engine level selector** — sets the filter level inside the Rust core.
    - **View filter** — client-side level filter (All / Error / Warn / Info / Debug).
    - Color-coded level badges (red=Error, orange=Warn, blue=Info, grey=Debug).
    - Copy-all and Clear buttons per tab.
    - Fetch button to request the full log buffer from the engine.

#### CI & Deployment (`windows-ci.yml`, `release.yml`)
- Added PJSIP cache step (`actions/cache@v4`; key hashes `.gitmodules` + `pjproject_config_site.h`).
- Added **Build pjproject (Release x64)** step (runs `build_pjsip.ps1`; skipped on cache hit).
- Added **Show PJSIP build output** inspection step (`if: always()`).
- `cargo build --release` now passes `PJSIP_LIB_DIR` and `PJSIP_INCLUDE_DIR` env vars
  so `build.rs` auto-links PJSIP libs when built in CI.

#### Development setup (`setup_windows.ps1`)
- Added PJSIP build step (step 5) with stamp-file idempotency check; initialises submodule if missing.
- Rust build step now exports `PJSIP_LIB_DIR` / `PJSIP_INCLUDE_DIR` before `cargo build`.

#### Docs
- `docs/FFI_API.md` — added `SetLogLevel`, `GetLogBuffer` commands and `LogLevelSet`,
  `EngineLog`, `LogBufferResult` events; added `CredStore`, `CredRetrieve`, `EnginePing`
  (previously undocumented).

---

## [Unreleased] — M6 Hardening & TLS

### Fixed

#### CI (`windows-ci.yml`)
- **Root cause of `flutter build windows` CMake failure**: `app_flutter/windows/flutter/`
  was listed in `.gitignore`, so the Flutter-managed CMake files (`CMakeLists.txt`,
  `generated_plugin_registrant.*`, `generated_plugins.cmake`) were never committed.
  Removed the `.gitignore` entry so those files are now tracked and present in the
  working tree when `cmake` runs on GitHub Actions.

### Added

#### Rust core (`core_rust/src/lib.rs`)
- **`Account.tls_enabled`** — flag to use TLS transport (SIP over TLS / SIPS URI scheme).
  Read from `AccountUpsert` payload (`"tls_enabled": true`); defaults to `false`.
- **`Account.srtp_enabled`** — flag to require SRTP media encryption. Defaults to `false`.
- **`AccountSetSecurity` command** — update TLS/SRTP flags on an existing account at runtime.
  Emits `AccountSecurityUpdated` event. TODO: apply to PJSIP transport + SRTP policy in M7.
- **`CredStore` command** — store a named credential in the in-memory credential store.
  Emits `CredStored` event. TODO: persist via Windows Credential Manager in M7.
- **`CredRetrieve` command** — retrieve a named credential; emits `CredRetrieved` or
  returns `NotFound`.
- **`EnginePing` command** — liveness / health-check probe; emits `EnginePong`.
- **Panic recovery** — `engine_init`, `engine_shutdown`, `engine_send_command`, and
  `engine_poll_event` are now wrapped with `std::panic::catch_unwind(AssertUnwindSafe(…))`.
  Any Rust panic inside the engine core returns `EngineErrorCode::InternalError` (100) instead
  of unwinding across the FFI boundary (undefined behaviour).
- **5 new unit tests** (20 total): `account_tls_srtp_flags`, `account_set_security_not_found`,
  `cred_store_and_retrieve`, `cred_retrieve_not_found`, `engine_ping_pong`.

#### Flutter app
- **`Account` model** — extended with `tlsEnabled` and `srtpEnabled` boolean fields
  (both default `false`); `copyWith` updated accordingly.
- **`AccountsScreen`** — add/edit dialog now shows two `CheckboxListTile` entries:
  *Enable TLS (SIPS)* and *Enable SRTP*. Both values are passed in `AccountUpsert`.
  Account list subtitle shows `+ TLS` / `+ SRTP` badges when enabled.

---

## [Unreleased] — M5 Windows Build

### Added

#### Flutter Windows runner (`app_flutter/windows/`)
- **`windows/CMakeLists.txt`** — top-level CMake; `BINARY_NAME = PacketDial`;
  bundles `voip_core.dll` from `core_rust/target/release/` via CMake `install()`
- **`windows/flutter/`** — Flutter engine CMake integration, plugin registrant
  stubs (`generated_plugin_registrant.cc/.h`), empty plugin list
  (`generated_plugins.cmake`)
- **`windows/runner/`** — Win32 C++ application runner:
  - `main.cpp` — `wWinMain` entry point; opens 1280×720 window titled "PacketDial"
  - `flutter_window.cpp/.h` — Flutter embedding window subclass
  - `win32_window.cpp/.h` — DPI-aware Win32 base window (per-monitor V2)
  - `run_loop.cpp/.h` — Win32 message loop
  - `utils.cpp/.h` — `CreateAndAttachConsole`, `Utf8FromUtf16`,
    `GetCommandLineArguments`
  - `resource.h` / `Runner.rc` — Windows version block; `PacketDial.exe` metadata
  - `runner.exe.manifest` — PerMonitorV2 DPI awareness, Windows 10/11 compatibility
  - `resources/app_icon.ico` — app icon (16×16, indigo, 32bpp)

#### Flutter app
- **`ffi/engine.dart`** — fixed `calloc` import: `dart:ffi` does not expose
  `calloc`; now imports `package:ffi/ffi.dart as ffi_alloc` and uses
  `ffi_alloc.calloc` — resolves Dart compile error
- **`pubspec.yaml`** — updated description to "PacketDial - Windows SIP softphone"

#### CI (`windows-ci.yml`)
- Removed all `continue-on-error: true` — `cargo build --release` and
  `flutter build windows --release` now succeed with the Windows runner present
- Reordered steps: `cargo test` before `cargo build --release`
- Added **"Copy voip_core.dll into Flutter output"** step: copies
  `core_rust/target/release/voip_core.dll` into
  `app_flutter/build/windows/x64/runner/Release/` so `PacketDial.exe` can
  load it at startup

---

## [Unreleased] — M4 Packaging

### Added

#### CI (`windows-ci.yml`)
- **Fixed**: replaced `flutter-version: "stable"` (invalid) with `channel: stable`
  in `subosito/flutter-action@v2` — resolves "Unable to determine Flutter version" failure
- Added `dtolnay/rust-toolchain@stable` `targets: x86_64-pc-windows-msvc`
- Added `actions/cache@v4` for `~\.cargo` and `core_rust\target`
- Run `cargo test` (Rust core) on Windows in CI
- Upload `PacketDial-windows-x64.zip` as a GitHub Actions artifact via
  `actions/upload-artifact@v4`
- Removed obsolete `setup-python`, `bootstrap_flutter.ps1`, `build_pjsip.ps1`,
  `build_core.ps1` steps (replaced by explicit `cargo build` / `flutter build`)

#### Packaging
- `version.json` — single-source version, build number, channel, and
  minimum Windows version
- `scripts/package.ps1` — PowerShell packaging script: copies Flutter Windows
  release output + `voip_core.dll` + `version.json` into a staging directory,
  then compresses to `dist/PacketDial-windows-x64.zip`

#### Docs
- `README.md` — rewritten: prerequisite list, quick-start commands, CI badges,
  architecture diagram, milestone status table

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

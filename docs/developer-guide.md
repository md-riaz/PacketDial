# PacketDial Developer Guide

This guide is the current starting point for developers working on PacketDial. Read this before diving into the code.

## What PacketDial Is

PacketDial is a Windows desktop SIP softphone built from three layers:

1. `app_flutter/`: Flutter desktop UI, app state, persistence, and UX flows.
2. `core_rust/`: Rust engine DLL (`voip_core.dll`) that owns runtime SIP/call/account state and bridges Flutter to PJSIP.
3. `engine_pjsip/`: vendored PJSIP source used by the native shim.

At runtime, Flutter talks to Rust over direct FFI. Rust talks to PJSIP through a thin C shim in `core_rust/src/shim/`.

## Current Architecture

### Runtime flow

1. Flutter starts in [`app_flutter/lib/main.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/main.dart).
2. `VoipEngine.load()` opens `voip_core.dll`.
3. `EngineChannel` attaches the Rust event callback and normalizes native events for Flutter services and screens.
4. `AccountService`, `AppSettingsService`, and `ContactsService` load local persisted JSON state from `%APPDATA%\PacketDial\`.
5. Rust initializes PJSIP and emits structured events such as `RegistrationStateChanged`, `CallStateChanged`, `BlfStatus`, and recording events.
6. Flutter providers and services update the UI and local persistence in response.

### Ownership model

- Rust owns live SIP engine state:
  - registered accounts in memory
  - active calls
  - PJSIP account and call ID mappings
  - native audio operations
  - native call recording lifecycle
- Flutter owns app persistence and most UX-facing configuration:
  - accounts JSON
  - app settings JSON
  - contacts JSON
  - call history JSON
  - selection state, filters, dialogs, navigation

### Important current design decisions

- Call history is Flutter-owned. Rust no longer exposes the old `CallHistoryResult` flow.
- DND is global, not per-account.
- Local recording is native WAV capture only. The UI should not imply MP3 capture.
- If no recording folder is configured, recordings default to `Desktop\Recordings`.
- Versioning no longer uses `version.json`. Release scripts derive from `app_flutter/pubspec.yaml`, and CI also syncs `core_rust/Cargo.toml`.

## Repository Map

### Top-level

- `app_flutter/`: Flutter Windows app
- `core_rust/`: Rust `cdylib` and C shim
- `engine_pjsip/`: vendored pjproject source
- `scripts/`: Windows setup, build, packaging, and dev-loop scripts
- `installer/`: Inno Setup resources
- `docs/`: developer and operational documentation
- `tools/`: auxiliary tools such as the `pd` CLI

### Flutter app

Key folders under `app_flutter/lib/`:

- `core/`: non-UI services and orchestration
- `ffi/`: raw dynamic library loading and FFI bindings
- `models/`: persisted schemas and view models
- `providers/`: Riverpod providers for reactive app state
- `screens/`: major pages and overlays
- `widgets/`: reusable UI components

Files worth reading first:

- [`app_flutter/lib/main.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/main.dart)
- [`app_flutter/lib/core/engine_channel.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart)
- [`app_flutter/lib/ffi/engine.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/ffi/engine.dart)
- [`app_flutter/lib/core/account_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/account_service.dart)
- [`app_flutter/lib/core/app_settings_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/app_settings_service.dart)
- [`app_flutter/lib/core/contacts_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/contacts_service.dart)
- [`app_flutter/lib/core/recording_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/recording_service.dart)

### Rust core

Key files:

- [`core_rust/src/lib.rs`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)
- [`core_rust/src/shim/pjsip_shim.c`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c)
- [`core_rust/src/shim/pjsip_shim.h`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.h)
- [`core_rust/build.rs`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/build.rs)

## Current Persistence Model

PacketDial currently uses file-based local storage in `%APPDATA%\PacketDial\`.

Primary files:

- `accounts.json`
- `call_history.json`
- `app_settings.json`
- `blf_contacts.json`

Relevant services:

- [`account_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/account_service.dart)
- [`app_settings_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/app_settings_service.dart)
- [`contacts_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/contacts_service.dart)

Note: the Flutter app still includes Isar packages and generated schema files, but the active persistence path is JSON-file based. Do not assume the current runtime depends on Isar unless you confirm the specific path you are touching.

## Feature Areas

### Accounts

- Accounts are stored in Flutter and mirrored into Rust with `AccountUpsert`.
- Registration/unregistration happens through Rust commands and Rust emits registration state changes.
- The dialer now uses a top-of-screen account selector instead of a modal chooser when multiple accounts exist.

### Calls

- Active call state comes from Rust events.
- The incoming call UX forces navigation back to the Dialer tab so the banner is visible.
- Global DND is pushed into Rust so rejection happens at the native layer.
- A second incoming call is rejected natively with `486 Busy Here` when another live call already exists.

### Call history

- History is written by Flutter to `call_history.json`.
- History classification depends on live call event timing handled in `EngineChannel`.
- Old Rust history APIs and docs are obsolete.

### BLF contacts and presence

- Contacts are managed in Flutter.
- BLF subscriptions are issued from the Contacts screen using a registered account.
- Presence matching normalizes full SIP URIs and extension-only targets.
- Contact tiles should show one presence badge, not duplicated text.
- Presence debugging currently relies on verbose logs from `contacts_screen.dart` and `contacts_service.dart`.

### Recording

- Native capture is done in PJSIP through the shim.
- Recording state is tracked per call in Flutter.
- Local auto-record is an app-level setting, but recording actions are per call.
- Saved format is WAV.
- Default fallback folder is `Desktop\Recordings` when no custom path is set.

### Settings and integrations

- Settings are grouped in the main Settings screen.
- Local call recording lives under normal call settings, not the integration page.
- Integration settings now focus on optional external automation such as webhooks, screen pop, lookup, clipboard, and recording upload.
- Settings import/export has been removed from the main UI.

## Build and Run

### First-time Windows setup

```powershell
.\scripts\setup_windows.ps1
```

### Build PJSIP

```powershell
.\scripts\build_pjsip.ps1
```

### Build Rust core

```powershell
.\scripts\build_core.ps1 -Configuration Debug
.\scripts\build_core.ps1 -Configuration Release
```

### Run the app in the normal dev loop

```powershell
.\scripts\run_app.ps1
```

This is the preferred inner loop when changing Flutter plus Rust together.

## Testing

### Flutter

```powershell
cd app_flutter
flutter analyze
flutter test
```

### Rust

```powershell
cd core_rust
cargo build
cargo test --lib
```

## Release and Packaging

Current release source of truth:

- Flutter app version: `app_flutter/pubspec.yaml`
- Rust package version: `core_rust/Cargo.toml`

Relevant files:

- [`scripts/package.ps1`](/C:/Users/vm_user/Downloads/PacketDial/scripts/package.ps1)
- [`scripts/build_package.ps1`](/C:/Users/vm_user/Downloads/PacketDial/scripts/build_package.ps1)
- [`scripts/build_installer.ps1`](/C:/Users/vm_user/Downloads/PacketDial/scripts/build_installer.ps1)
- [`.github/workflows/release.yml`](/C:/Users/vm_user/Downloads/PacketDial/.github/workflows/release.yml)

The older `version.json` release manifest has been removed.

## Recommended Reading Order

1. [`docs/developer-guide.md`](/C:/Users/vm_user/Downloads/PacketDial/docs/developer-guide.md)
2. [`docs/architecture.md`](/C:/Users/vm_user/Downloads/PacketDial/docs/architecture.md)
3. [`app_flutter/lib/main.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/main.dart)
4. [`app_flutter/lib/core/engine_channel.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart)
5. [`core_rust/src/lib.rs`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)
6. [`core_rust/src/shim/pjsip_shim.c`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c)

## Common Sources of Confusion

- Some older docs still describe features that were removed or changed. Prefer this guide and the code over older narrative docs.
- Some direct FFI methods still exist alongside `engine_send_command(...)`. The active app uses both.
- Some generated or legacy model files still exist, but that does not mean the runtime path still uses them.
- Presence issues are often either subscription-target problems or PBX-specific BLF URI expectations, not only UI bugs.

## When Updating the Code

Keep these rules in mind:

- If you add or rename a Rust event, update:
  - `core_rust/src/lib.rs`
  - `app_flutter/lib/ffi/engine.dart`
  - `app_flutter/lib/core/engine_channel.dart`
- If you change persisted settings or account fields, update:
  - the service that reads/writes the JSON
  - the relevant schema/model
  - migration/default handling for missing old fields
- If you change recording behavior, verify both:
  - manual per-call recording
  - app-level automatic recording
- If you change presence behavior, test:
  - extension-only contacts
  - full SIP URI contacts
  - add/edit/delete and refresh flows

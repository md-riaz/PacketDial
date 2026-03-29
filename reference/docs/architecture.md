# Architecture

## Overview

PacketDial is a three-layer Windows desktop softphone:

```text
Flutter Desktop UI
    <-> Dart FFI bindings + EngineChannel
Rust core (voip_core.dll)
    <-> C shim
PJSIP
```

The live application is Flutter-driven, Rust-backed, and PJSIP-powered.

## Layer Responsibilities

### Flutter

Flutter owns:

- app shell and navigation
- settings UI
- account management UI
- call history persistence
- contacts and BLF UI
- recording UX
- integration UX
- footer, tray, and incoming-call page behavior

Main entrypoints:

- [`app_flutter/lib/main.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/main.dart)
- [`app_flutter/lib/core/engine_channel.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart)

### Rust core

Rust owns:

- exported FFI surface
- runtime account map and call map
- structured command dispatch
- event serialization and delivery
- PJSIP account and call ID mappings
- global DND enforcement
- native recording coordination
- audio-device enumeration and selection

Main file:

- [`core_rust/src/lib.rs`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/lib.rs)

### PJSIP shim

The C shim isolates direct PJSIP interactions from Rust:

- account add/remove/register helpers
- call make/answer/hangup
- transfer and conference helpers
- BLF subscribe/unsubscribe callbacks
- recorder setup and teardown
- incoming-call policy enforcement such as DND and busy rejection

Main files:

- [`core_rust/src/shim/pjsip_shim.c`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.c)
- [`core_rust/src/shim/pjsip_shim.h`](/C:/Users/vm_user/Downloads/PacketDial/core_rust/src/shim/pjsip_shim.h)

## Data Ownership

Current split:

- Rust: transient engine state
- Flutter: persisted user/application state

Persisted files live under `%APPDATA%\PacketDial\` and include:

- `accounts.json`
- `call_history.json`
- `app_settings.json`
- `blf_contacts.json`

This matters because some older docs still describe Rust-owned call history or broader native persistence. That is no longer the current model.

## Event Flow

Typical call/event flow:

1. Flutter issues a command through direct FFI or `engine_send_command(...)`.
2. Rust validates it, updates in-memory state, and calls the shim.
3. PJSIP callbacks return into the shim.
4. Rust converts native callbacks into structured JSON events.
5. Flutter receives the event callback and updates services, providers, and UI.

Representative events:

- `RegistrationStateChanged`
- `CallStateChanged`
- `MediaStatsUpdated`
- `AudioDeviceList`
- `SipMessageCaptured`
- `BlfStatus`
- `GlobalDndUpdated`
- `RecordingStarted`
- `RecordingStopped`
- `RecordingSaved`
- `RecordingError`

## Current Behavioral Rules

- DND is global.
- Concurrent incoming calls are rejected with busy when another live call already exists.
- Call history is written in Flutter, not exported from Rust.
- Local recording is native WAV capture.
- The Dialer page is the primary surface for active and incoming calls.

## Extension Points

The code is easiest to extend by area:

- add UI/state behavior in Flutter services, providers, and screens
- add engine behavior in Rust command handlers and event emitters
- add PJSIP operations only in the shim

When adding a new event or command, update all three layers together.

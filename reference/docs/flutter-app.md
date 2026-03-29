# Flutter App

Current overview of the Flutter desktop application in `app_flutter/`.

## What Flutter Owns

Flutter is responsible for:

- app bootstrap and window setup
- navigation and shell UI
- account management flows
- contacts UI and BLF subscription orchestration
- call history persistence
- settings persistence
- recording UX and folder selection
- integration features such as webhooks, screen pop, lookup, and clipboard helpers

## Important Entry Points

- [`app_flutter/lib/main.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/main.dart): startup, engine boot, shell, footer, incoming-call navigation handling
- [`app_flutter/lib/core/engine_channel.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/engine_channel.dart): native event intake and fan-out
- [`app_flutter/lib/ffi/engine.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/ffi/engine.dart): dynamic library bindings

## Current Folder Layout

```text
app_flutter/lib/
  core/       services and orchestration
  ffi/        raw Rust DLL bindings
  models/     schemas and runtime models
  providers/  Riverpod state
  screens/    main pages and overlays
  widgets/    shared UI pieces
```

## Persistence Model

The active persistence model is file-based JSON under `%APPDATA%\PacketDial\`.

Primary files:

- `accounts.json`
- `call_history.json`
- `app_settings.json`
- `blf_contacts.json`

Although Isar packages and generated files still exist in the repo, they are not the main active persistence path for the current app flow.

## Notable Services

- [`account_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/account_service.dart)
- [`app_settings_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/app_settings_service.dart)
- [`contacts_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/contacts_service.dart)
- [`recording_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/recording_service.dart)
- [`audio_service.dart`](/C:/Users/vm_user/Downloads/PacketDial/app_flutter/lib/core/audio_service.dart)

## Windows Integration

Key packages and behaviors:

- `window_manager` and `bitsdojo_window` for window behavior and chrome
- `tray_manager` for tray integration
- `hotkey_manager` for system hotkeys
- `package_info_plus` for runtime version display
- `internet_connection_checker_plus` for footer network reachability

## Window Sizing and Resize Behavior

The app enforces a minimum window size of `400×750` at the OS level via `windowManager.setMinimumSize` — called before geometry restore so it is active from the first frame. A snap-back guard in `onWindowResized` corrects any edge-case slip below the minimum.

When the window is resized larger, the UI content stays at a fixed max width (`450px`) and is centered in the window — extra space shows the background. This mirrors MicroSIP's behavior and prevents layout breakage on wide windows.

A resize lock toggle (lock icon in the title bar) lets users pin the window to its current size. The lock state is persisted in `window_prefs.json` and defaults to locked. When unlocked, only the minimum size floor is enforced.

`WindowPrefs` (`core/window_prefs.dart`) persists:
- `window_x`, `window_y` — last position
- `window_w`, `window_h` — last size (clamped to minimum on restore)
- `always_on_top` — pin-on-top state
- `resize_locked` — resize lock state (default: `true`)

## Current UX Notes

- Incoming calls force the app back to the Dialer tab so the banner is visible.
- The dialer uses a top account dropdown instead of a call-start modal chooser.
- Local call recording controls live in the main Settings page under call settings.
- Settings import/export was removed from the main settings UI.

For the broader current-state view, read [`docs/developer-guide.md`](/C:/Users/vm_user/Downloads/PacketDial/docs/developer-guide.md).

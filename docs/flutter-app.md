# Flutter Windows Desktop App (`app_flutter/`)

This document describes the PacketDial Flutter UI and Windows-specific integration.

---

## Overview

**PacketDial** is a Flutter Desktop application for Windows 10/11 that:

- Provides a modern, native Windows UI for SIP calling
- Communicates with Rust core (`voip_core.dll`) via Dart FFI
- Uses Windows platform channels for system integration (tray, notifications, hotkeys)
- Stores local data with Isar database

---

## Directory Structure

```
app_flutter/
├── pubspec.yaml                    # Dart dependencies & app metadata
├── lib/
│   ├── main.dart                   # App entry point
│   ├── core/
│   │   ├── engine_channel.dart     # Dart FFI wrapper, commands/events
│   │   ├── engine_provider.dart    # State management (Riverpod)
│   │   ├── tray_controller.dart    # Windows tray integration
│   │   └── account_service.dart    # Account/credential management
│   ├── models/
│   │   ├── account.dart            # Account schema (Isar model)
│   │   ├── call.dart               # Call state machine
│   │   ├── audio_device.dart       # Audio device enumeration
│   │   └── ...                     # Other data models
│   └── screens/
│       ├── dialer_screen.dart      # Main dialer UI
│       ├── accounts_screen.dart    # Manage SIP accounts
│       ├── active_call_screen.dart # In-call UI
│       ├── history_screen.dart     # Call history
│       └── diagnostics_screen.dart # SIP logs & stats
├── windows/
│   ├── CMakeLists.txt             # Windows build configuration
│   ├── runner/
│   │   ├── main.cpp               # Windows entry point
│   │   ├── runner.rc              # Resource file (icon, version)
│   │   └── CMakeLists.txt         # Post-build steps (copy voip_core.dll)
│   └── flutter/
│       └── ...                    # Generated Flutter files
└── build/
    └── windows/
        └── x64/
            └── runner/            # Build output
                ├── Debug/         # Debug build (with debug DLL)
                └── Release/       # Release build (with optimized DLL)
```

---

## Dependencies (pubspec.yaml)

Key packages used:

| Package | Version | Purpose |
|---------|---------|---------|
| `ffi` | ^2.1.0 | Raw FFI bindings to voip_core.dll |
| `flutter_riverpod` | ^3.2.1 | State management (accounts, call state) |
| `isar` | ^3.1.0+1 | Local database (accounts, call history) |
| `window_manager` | - | Window chrome (minimize, maximize, close) |
| `bitsdojo_window` | - | Custom window decorations |
| `tray_manager` | - | Windows system tray integration |
| `local_notifier` | - | Desktop notifications |
| `hotkey_manager` | - | Keyboard shortcuts (answer/hangup) |

---

## FFI Integration

### How Flutter Calls Rust

**File:** `app_flutter/lib/core/engine_channel.dart`

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Load the DLL
final dylib = DynamicLibrary.open('voip_core.dll');

// Define FFI signatures
typedef engine_send_command_t = Pointer<Utf8> Function(Pointer<Utf8>);
typedef engineSendCommand = Pointer<Utf8> Function(Pointer<Utf8>);

// Bind to exported functions
final Pointer<Utf8> Function(Pointer<Utf8>) engineSendCommand =
    dylib
        .lookup<NativeFunction<engine_send_command_t>>('engine_send_command')
        .asFunction();

// Send a command
final result = engineSendCommand('{"cmd":"register",...}'.toNativeUtf8());
```

### Command/Event Pattern

1. **Dart sends command**:
   ```dart
   final jsonCmd = jsonEncode({
     'cmd': 'register',
     'user': 'alice',
     'pass': 'secret',
     'domain': 'sip.example.com'
   });
   final result = engineSendCommand(jsonCmd);
   ```

2. **Rust receives and processes**:
   ```rust
   #[no_mangle]
   pub extern "C" fn engine_send_command(cmd: *const c_char) -> *const c_char {
       let cmd_str = parse_cstring(cmd);
       let resp = handle_command(cmd_str);
       return cstring_to_ptr(resp);
   }
   ```

3. **Dart polls for events**:
   ```dart
   final event = enginePollEvent(); // Non-blocking
   // Parse event JSON and update UI state
   ```

---

## Windows-Specific Integration

### CMakeLists.txt (Build Configuration)

**File:** `app_flutter/windows/CMakeLists.txt`

Key responsibilities:

1. **copies voip_core.dll** to the build output directory (Debug or Release)
2. **Sets Windows SDK version** (10.0.22621 or later)
3. **Enables DLL linking** for FFI bindings

```cmake
# Copy DLL post-build
add_custom_command(TARGET runner POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/../../core_rust/target/x86_64-pc-windows-msvc/$<CONFIG>/voip_core.dll"
        "$<TARGET_FILE_DIR:runner>/voip_core.dll"
    COMMENT "Copying voip_core.dll"
)

# Link Windows system libraries (required for some Windows APIs)
target_link_libraries(runner PRIVATE ws2_32 ole32 uuid)
```

### Tray Integration

**File:** `app_flutter/lib/core/tray_controller.dart`

Integrates with Windows system tray:

```dart
class TrayController {
  Future<void> setupTray() async {
    await trayManager.setIcon(
      'assets/icon.ico',  // Icon in system tray
    );
    
    // Right-click menu
    final menuItems = [
      MenuItem(label: 'Open', onClick: () => /* show window */),
      MenuItem(label: 'Quit', onClick: () => /* exit app */),
    ];
    await trayManager.setContextMenu(Menu(items: menuItems));
  }

  // Right-click on tray icon
  onTrayIconRightMouseDown() => trayManager.popUpContextMenu();
}
```

### Hotkey Support

**File:** `app_flutter/lib/core/engine_channel.dart`

Register global hotkeys (even when app is minimized):

```dart
await hotkeyManager.register(
  HotKey(
    key: PhysicalKeyboardKey.f6,         // F6 to answer
  ),
  handler: (hotkey) => answerCall(),
);

await hotkeyManager.register(
  HotKey(
    key: PhysicalKeyboardKey.f7,         // F7 to hang up
  ),
  handler: (hotkey) => hangupCall(),
);
```

---

## State Management (Riverpod)

PacketDial uses **Flutter Riverpod** for reactive state:

**Key providers** (`app_flutter/lib/core/engine_provider.dart`):

```dart
// Current account being used
final currentAccountProvider = StateProvider<Account?>((ref) => null);

// Call state (idle, ringing, connected, etc)
final callStateProvider = StateProvider<CallState>((ref) => CallState.idle);

// List of registered accounts
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  return await accountService.getAllAccounts();
});

// Real-time event stream from Rust
final engineEventProvider = StreamProvider<EngineEvent>((ref) async* {
  while (true) {
    final event = await pollEngineEvents();
    yield event;
  }
});
```

UI rebuilds automatically when these providers change:

```dart
Consumer(builder: (context, ref, child) {
  final callState = ref.watch(callStateProvider);
  return Text('Call State: $callState');
}),
```

---

## Database (Isar)

PacketDial stores accounts and call history locally with **Isar**:

**Models** (`app_flutter/lib/models/`):

```dart
// Account schema
@collection
class Account {
  late String accountId;
  late String username;
  late String domain;
  late String? password;  // Optional (can use credential store)
  late DateTime createdAt;
}

// Call history
@collection
class Call {
  late String callId;
  late String accountId;
  late String remoteParty;
  late DateTime startTime;
  late int durationSeconds;
  late String direction;  // "inbound" | "outbound"
}
```

**Usage**:

```dart
// Open database
final isar = await Isar.open([AccountSchema, CallSchema]);

// Add account
await isar.writeTxn(() async {
  await isar.accounts.put(Account(/* ... */));
});

// Query call history
final calls = await isar.calls
    .filter()
    .accountIdEqualTo('acc123')
    .findAll();
```

---

## Build Configuration

### Debug (Development)

```powershell
.\scripts\run_app.ps1
# or manually:
cd app_flutter
flutter run -d windows      # Debug build + hot-reload
```

Output: `app_flutter/build/windows/x64/runner/Debug/`

### Release (Distribution)

```powershell
cd app_flutter
flutter build windows --release
# then:
.\scripts\package.ps1       # Creates distributable ZIP
```

Output: `app_flutter/build/windows/x64/runner/Release/`

---

## Common Tasks

### Add a New Screen

1. Create file: `app_flutter/lib/screens/my_screen.dart`
   ```dart
   class MyScreen extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       return Scaffold(
         appBar: AppBar(title: Text('My Screen')),
         body: Center(child: Text('Content here')),
       );
     }
   }
   ```

2. Add navigation in main.dart or router

3. Test with hot-reload: Press `r` in Flutter terminal

### Send a Command to Rust

1. Define in `engine_channel.dart`:
   ```dart
   Future<String> registerAccount(String user, String pass, String domain) async {
     return engineSendCommand(jsonEncode({
       'cmd': 'register',
       'user': user,
       'pass': pass,
       'domain': domain,
     }));
   }
   ```

2. Use in a widget:
   ```dart
   onPressed: () async {
     final result = await registerAccount('alice', 'secret', 'sip.example.com');
     // Handle result
   }
   ```

### Modify the Windows Runner

If you need to customize the C++ entry point or CMake build:

1. Edit: `app_flutter/windows/runner/main.cpp` or `app_flutter/windows/CMakeLists.txt`
2. Rebuild: `flutter clean && flutter build windows`

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **"DLL not found" at runtime** | Ensure `voip_core.dll` exists in the same directory as `PacketDial.exe` (copy is done by CMakeLists.txt) |
| **FFI signature mismatch** | Ensure Dart FFI types match Rust export C signatures exactly (pointer types, memory management) |
| **"package not found" errors** | Run `flutter pub get` before building |
| **Hot-reload fails** | Press `R` (restart) instead; if issues persist, exit and re-run `.\scripts\run_app.ps1` |
| **Window doesn't appear** | Check Windows Desktop support: `flutter config --enable-windows-desktop` |
| **Tray icon not showing** | Ensure icon asset is included in `pubspec.yaml` under assets |

---

## See Also

- [Developer Workflow](dev-workflow.md) — Hot-reload and debugging
- [FFI API Reference](FFI_API.md) — Complete function signatures
- [Official Flutter Docs](https://docs.flutter.dev/) — General Flutter
- [Official Riverpod Docs](https://riverpod.dev/) — State management

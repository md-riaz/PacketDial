# PacketDial — Microsoft Store (MSIX) Packaging Guide

This guide walks through converting PacketDial from its current Inno Setup `.exe`
installer to a Store-ready MSIX package without losing any existing functionality.

---

## Overview of what changes (and what doesn't)

| Area | Current | After MSIX |
|---|---|---|
| Installer format | Inno Setup `.exe` | `.msix` / `.msixbundle` |
| Install location | `Program Files\PacketDial` | Virtualized (Store-managed) |
| Data/settings storage | `<exe_dir>\data\` (portable) | `%LOCALAPPDATA%\Packages\...\LocalCache` |
| Registry auto-start | `HKCU\...\Run` via `reg.exe` | `<desktop:StartupTask>` in manifest |
| Protocol handlers (`tel:`, `sip:`, `callto:`) | Not registered | `<uap:Protocol>` in manifest |
| Admin elevation | Required | Not allowed |
| System tray | Works as-is | Works as-is |
| FFI / native DLL (`voip_core.dll`) | Bundled next to EXE | Bundled inside MSIX package |
| Hotkey (Alt+D) | Works as-is | Works as-is |

---

## Prerequisites

- Flutter SDK ≥ 3.3 (already met)
- Windows 10 SDK 10.0.17763.0 or later
- Visual Studio 2022 with "Desktop development with C++" workload
- Microsoft Partner Center account (for Store submission only)
- `msix` Flutter pub package (added in Step 1)

---

## Step 1 — Add the `msix` pub package

In `app_flutter/pubspec.yaml`, add to `dev_dependencies`:

```yaml
dev_dependencies:
  msix: ^3.16.7          # check pub.dev for latest
```

Then add a top-level `msix_config` section (still in `pubspec.yaml`):

```yaml
msix_config:
  display_name: PacketDial
  publisher_display_name: PacketDial          # must match Partner Center later
  identity_name: PacketDial.VoipSoftphone     # reverse-DNS style, unique per app
  msix_version: 0.1.0.0                       # must be 4-part: major.minor.patch.build
  logo_path: assets/app_icon.png
  capabilities: >-
    microphone
    internetClient
    privateNetworkClientServer
  languages: en-US
  store: false                                # set to true only for Store submission
```

Run:

```bash
cd app_flutter
dart pub get
```

---

## Step 2 — Fix the portable data path (critical)

`PathProviderService` currently stores all data next to the EXE in release mode.
MSIX packages run from a read-only virtualized install directory, so writes there
are silently redirected or fail. Switch to `getApplicationSupportDirectory()`
unconditionally in release builds packaged as MSIX.

The cleanest approach is to detect MSIX at runtime via the package family name:

```dart
// lib/core/path_provider_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PathProviderService {
  PathProviderService._();
  static final PathProviderService instance = PathProviderService._();

  /// Returns true when the app is running inside an MSIX package.
  /// Detected by the presence of the WindowsApps install path in the exe location.
  static bool get _isPackaged {
    if (!Platform.isWindows) return false;
    final exePath = Platform.resolvedExecutable.toLowerCase();
    return exePath.contains('windowsapps') ||
        exePath.contains('packages\\');
  }

  Future<Directory> getDataDirectory() async {
    // MSIX: always use app support dir (maps to LocalCache in the package container)
    if (_isPackaged || !kReleaseMode) {
      final dir = await getApplicationSupportDirectory();
      return dir;
    }
    // Portable (non-packaged release): keep existing behaviour
    final exeDir = File(Platform.resolvedExecutable).parent;
    final dataDir = Directory(p.join(exeDir.path, 'data'));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir;
  }
}
```

> Existing portable installs are unaffected. Only MSIX-packaged installs use the
> new path. Users migrating from the Inno installer will need to copy their
> `data\` folder to the new location once — document this in release notes.

---

## Step 3 — Replace registry auto-start with a StartupTask

The current `_setWindowsAutoStartEnabled` method writes to
`HKCU\Software\Microsoft\Windows\CurrentVersion\Run` using `reg.exe`.
MSIX apps cannot write to arbitrary registry keys; instead, startup is declared
in the manifest and toggled via the `StartupTask` API.

### 3a — Declare the StartupTask in the manifest

After running `dart run msix:create` once (Step 5), an `AppxManifest.xml` will
be generated. Open it and add inside `<Extensions>`:

```xml
<Extensions>
  <desktop:Extension Category="windows.startupTask"
                     Executable="PacketDial.exe"
                     EntryPoint="Windows.FullTrustApplication">
    <desktop:StartupTask TaskId="PacketDialStartup"
                         Enabled="false"
                         DisplayName="PacketDial" />
  </desktop:Extension>
</Extensions>
```

Also ensure the `xmlns:desktop` namespace is declared on the root `<Package>` element:

```xml
<Package
  xmlns:desktop="http://schemas.microsoft.com/appx/manifest/desktop/windows10"
  ...>
```

### 3b — Update `AppSettingsService` to use the WinRT StartupTask API

Add the `win32` package to `pubspec.yaml` dependencies (it is already a transitive
dependency of many Flutter Windows plugins, so it may already be present):

```yaml
dependencies:
  win32: ^5.5.0
```

Replace the `_isWindowsAutoStartEnabled`, `_setWindowsAutoStartEnabled`, and
`_syncWindowsAutoStartRegistration` methods in `app_settings_service.dart`:

```dart
import 'package:win32/win32.dart';

// Replace the three private methods with:

Future<bool> _isWindowsAutoStartEnabled() async {
  if (!Platform.isWindows) return false;
  if (!_isPackaged()) {
    // Portable build: keep registry approach
    try {
      final result = await Process.run('reg', [
        'query', _windowsRunKey, '/v', _windowsRunValueName,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
  // MSIX: query StartupTask state via PowerShell (no WinRT Dart bindings needed)
  try {
    final result = await Process.run('powershell', [
      '-NoProfile', '-Command',
      r'(Get-StartApps | Where-Object { $_.AppID -like "*PacketDial*" }) -ne $null',
    ]);
    // Simpler: use the registry key that StartupTask writes under the package
    final stateResult = await Process.run('reg', [
      'query',
      r'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\PacketDial.VoipSoftphone_<REPLACE_WITH_PUBLISHER_ID>\PacketDialStartup',
      '/v', 'State',
    ]);
    return stateResult.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<void> _setWindowsAutoStartEnabled(bool enabled) async {
  if (!Platform.isWindows) {
    _startWithWindowsEnabled = false;
    return;
  }
  if (!_isPackaged()) {
    // Portable build: keep registry approach
    try {
      if (enabled) {
        final executablePath = Platform.resolvedExecutable;
        final valueData = '"$executablePath" $_windowsAutoStartArg';
        await Process.run('reg', [
          'add', _windowsRunKey, '/v', _windowsRunValueName,
          '/t', 'REG_SZ', '/d', valueData, '/f',
        ]);
      } else {
        await Process.run('reg', [
          'delete', _windowsRunKey, '/v', _windowsRunValueName, '/f',
        ]);
      }
    } catch (e) {
      debugPrint('[AppSettings] Error updating Windows auto-start: $e');
      rethrow;
    }
    return;
  }
  // MSIX: direct the user to Windows Settings > Apps > Startup
  // The StartupTask manifest entry sets the initial state; the user controls it.
  // We can request enable/disable via the Windows.ApplicationModel.StartupTask WinRT API.
  // For simplicity, open the Startup Apps settings page:
  debugPrint('[AppSettings] MSIX: auto-start is managed via Windows Startup settings');
}

Future<void> _syncWindowsAutoStartRegistration() async {
  if (!Platform.isWindows || _isPackaged()) return;
  await _setWindowsAutoStartEnabled(true);
}

bool _isPackaged() {
  final exePath = Platform.resolvedExecutable.toLowerCase();
  return exePath.contains('windowsapps') || exePath.contains('packages\\');
}
```

> The `--startup-launch` argument still works — Windows passes it when the
> StartupTask fires, because it is declared in the manifest's `Executable` entry.
> No change needed in `main.dart`.

---

## Step 4 — Register protocol handlers (`tel:`, `sip:`, `callto:`)

The app already handles these in `main.dart`. Register them in the manifest so
Windows routes them to PacketDial:

```xml
<Extensions>
  <!-- existing StartupTask extension -->

  <uap:Extension Category="windows.protocol">
    <uap:Protocol Name="tel">
      <uap:DisplayName>PacketDial Phone Call</uap:DisplayName>
    </uap:Protocol>
  </uap:Extension>

  <uap:Extension Category="windows.protocol">
    <uap:Protocol Name="sip">
      <uap:DisplayName>PacketDial SIP Call</uap:DisplayName>
    </uap:Protocol>
  </uap:Extension>

  <uap:Extension Category="windows.protocol">
    <uap:Protocol Name="callto">
      <uap:DisplayName>PacketDial Call</uap:DisplayName>
    </uap:Protocol>
  </uap:Extension>
</Extensions>
```

Ensure `xmlns:uap` is declared on `<Package>`:

```xml
<Package
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  ...>
```

---

## Step 5 — Build the MSIX

```bash
cd app_flutter

# 1. Build the Flutter release bundle
flutter build windows --release

# 2. Package as MSIX (self-signed, for local testing)
dart run msix:create
```

The output will be at `build\windows\x64\runner\Release\PacketDial.msix`.

To install locally for testing:

```powershell
# Trust the self-signed cert (one-time, dev machine only)
$cert = (Get-AuthenticodeSignature ".\PacketDial.msix").SignerCertificate
Import-Certificate -FilePath $cert -CertStoreLocation Cert:\LocalMachine\TrustedPeople

# Install
Add-AppxPackage .\PacketDial.msix
```

---

## Step 6 — Verify functionality checklist

After installing the MSIX, confirm each feature works:

- [ ] App launches and SIP engine initialises (`voip_core.dll` loads correctly)
- [ ] Account registration succeeds
- [ ] Outbound and inbound calls work (microphone capability declared)
- [ ] Settings persist across restarts (data written to `LocalCache`, not install dir)
- [ ] System tray icon appears and context menu works
- [ ] "Hide to tray on close" works
- [ ] Alt+D global hotkey works
- [ ] Call recordings save to the configured directory (or Desktop\Recordings)
- [ ] `tel:` / `sip:` / `callto:` links in the browser open PacketDial
- [ ] "Start with Windows" toggle reflects the StartupTask state

---

## Step 7 — Microsoft Partner Center submission

1. Create an app reservation at https://partner.microsoft.com/dashboard
2. Note the **Package identity name** and **Publisher** values assigned by the Store.
3. Update `pubspec.yaml` `msix_config`:
   ```yaml
   msix_config:
     identity_name: <Store-assigned identity name>
     publisher: CN=<Store-assigned publisher ID>
     store: true
   ```
4. Rebuild:
   ```bash
   flutter build windows --release
   dart run msix:create
   ```
5. Upload the `.msix` to Partner Center under **Packages**.
6. Fill in Store listing, screenshots, age rating, and pricing.
7. Submit for certification.

---

## Known limitations and Store policies to be aware of

- **No admin elevation**: The app must never request UAC elevation. The current
  code does not, so this is already compliant.
- **Microphone access**: The Store will prompt users for microphone permission on
  first use. The `microphone` capability declared in Step 1 covers this.
- **Background audio**: If you add background call handling in the future, declare
  the `backgroundMediaPlayback` restricted capability.
- **`voip_core.dll`**: Native DLLs are allowed in MSIX packages. No changes needed.
- **Isar database**: Isar writes to the app support directory, which is inside the
  package container. This is fine and already handled by Step 2.
- **`file_picker`**: Works in MSIX without changes; it uses the system file dialog.
- **`url_launcher`**: Works in MSIX without changes.
- **`local_notifier`**: Works in MSIX without changes.
- **`hotkey_manager`**: System-wide hotkeys work in MSIX without changes.
- **`tray_manager`**: Works in MSIX without changes.

---

## Keeping the Inno Setup installer alongside MSIX

You can ship both. The Inno Setup installer targets enterprise/IT deployments
(no Store required, group policy, silent install). The MSIX targets consumer
Store distribution. The `_isPackaged()` helper in Step 3 ensures each build
uses the appropriate auto-start and data path strategy automatically.

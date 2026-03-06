# PacketDial Build & Installation Guide

## Quick Start

### For End Users

**Option 1: Installer (Recommended)**
```powershell
# Download PacketDial-Setup-X.X.X.exe
# Run the installer
# PacketDial will be installed to C:\Program Files\PacketDial
```

**Option 2: Portable**
```powershell
# Download PacketDial-X.X.X-Portable.zip
# Extract to any folder
# Run PacketDial.exe
# (Optional) Run CreateShortcut.bat to create Start Menu shortcut
```

---

## For Developers

### Prerequisites

1. **Visual Studio Build Tools 2022**
   - Desktop development with C++ workload
   - Windows 10 SDK

2. **Rust**
   ```powershell
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   rustup default stable
   rustup target add x86_64-pc-windows-msvc
   ```

3. **Flutter SDK**
   ```powershell
   # Download from https://flutter.dev
   # Or use the bundled version in vcpkg
   ```

4. **Inno Setup** (for installer)
   - Download from: https://jrsoftware.org/isdl.php#stable

### Build Commands

#### Complete Build (Everything)
```powershell
.\scripts\build_all.ps1 -Version 1.0.0
```

This will:
1. Build PJSIP (if needed)
2. Build Rust core
3. Run tests
4. Build Flutter app
5. Create portable ZIP
6. Create installer (if Inno Setup installed)

#### Individual Steps

**Build PJSIP:**
```powershell
.\scripts\build_pjsip.ps1
```

**Build Rust Core:**
```powershell
.\scripts\build_core.ps1 -Configuration Release
```

**Build Flutter App:**
```powershell
cd app_flutter
flutter build windows --release
```

**Create Portable Package:**
```powershell
.\scripts\build_package.ps1 -Version 1.0.0
```

**Create Installer:**
```powershell
.\scripts\build_installer.ps1 -Version 1.0.0
```

---

## Build Output

After a successful build, the `dist` folder will contain:

```
dist/
├── PacketDial-1.0.0-Portable.zip    # Portable version
├── PacketDial-Setup-1.0.0.exe       # Installer (if Inno Setup available)
└── (temporary build files)
```

---

## Installation Methods

### 1. Installer (Recommended for most users)

**Features:**
- Automatic installation to Program Files
- Start Menu shortcuts
- Desktop shortcut (optional)
- Uninstaller in Control Panel
- File associations

**Usage:**
1. Run `PacketDial-Setup-X.X.X.exe`
2. Follow installation wizard
3. Launch from Start Menu or Desktop

### 2. Portable (Recommended for testing/development)

**Features:**
- No installation required
- Can run from USB drive
- No admin rights needed
- Easy to remove (just delete folder)

**Usage:**
1. Extract ZIP to desired location
2. Run `PacketDial.exe`
3. (Optional) Run `CreateShortcut.bat` for Start Menu shortcut
4. (Optional) Run `UNINSTALL.bat` to remove

---

## Configuration Files

All configuration is stored in:
```
%APPDATA%\PacketDial\
├── app_settings.json    # App-wide settings
└── blf_contacts.json    # BLF contact list
```

These files persist across updates and uninstallation.

To completely remove all data:
```powershell
Remove-Item -Recurse -Force "$env:APPDATA\PacketDial"
```

---

## Troubleshooting

### Build Fails

**Error: PJSIP not found**
```powershell
.\scripts\build_pjsip.ps1
```

**Error: Rust toolchain not found**
```powershell
rustup install stable
rustup default stable
```

**Error: Flutter not found**
```powershell
flutter doctor
flutter upgrade
```

### Installer Creation Fails

**Error: Inno Setup not found**
- Install Inno Setup from https://jrsoftware.org/isdl.php
- Or use the portable ZIP package instead

### Application Issues

**First launch is slow**
- Normal - app is initializing configuration files

**Audio not working**
- Check Windows Sound settings
- Ensure microphone/speakers are connected
- Check app audio device settings

---

## Distribution

### For IT Administrators

**Silent Installation:**
```batch
PacketDial-Setup-X.X.X.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
```

**Deploy via Group Policy:**
1. Copy installer to network share
2. Create GPO with startup script:
   ```batch
   \\server\share\PacketDial-Setup-X.X.X.exe /VERYSILENT
   ```

**SCCM/Intune:**
- Use the installer with silent switches
- Or deploy portable version with shortcut

---

## Version Numbering

PacketDial uses semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

Example: `1.2.3` = Major 1, Minor 2, Patch 3

---

## Support

For issues:
1. Check logs in `%APPDATA%\PacketDial\logs\`
2. Run diagnostics from Settings → Diagnostics
3. Export diagnostic bundle for support

---

**PacketDial - Modern Windows SIP Client**

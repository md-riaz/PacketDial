# Troubleshooting Guide

Solutions for common PacketDial build and runtime issues.

---

## Table of Contents

1. [Setup & Installation Issues](#setup--installation-issues)
2. [Build Errors](#build-errors)
3. [Runtime Problems](#runtime-problems)
4. [DLL & FFI Issues](#dll--ffi-issues)
5. [Windows-Specific Issues](#windows-specific-issues)
6. [Performance & Optimization](#performance--optimization)

---

## Setup & Installation Issues

### PowerShell Execution Policy blocked

**Error:**
```
cannot be loaded because running scripts is disabled on this system
```

**Solution:**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\setup_windows.ps1
```

The `-Scope Process` flag allows the script to run only in the current PowerShell session (not system-wide).

---

### winget not found

**Error:**
```
winget: The term 'winget' is not recognized
```

**Solution:**

1. Update Windows to the latest version (Windows 10 build 1809+ or Windows 11)
2. Install **App Installer** from the Microsoft Store:
   - Open Microsoft Store
   - Search "App Installer"
   - Click **Get**
3. Close and reopen PowerShell
4. Retry: `.\scripts\setup_windows.ps1`

---

### Git installation fails

**Error:**
```
winget install Git.Git exited with code 1
```

**Solution:**

Download Git manually:

```powershell
# Download Git installer
Invoke-WebRequest `
    -Uri "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe" `
    -OutFile "$env:TEMP\Git-installer.exe"

# Run installer
& "$env:TEMP\Git-installer.exe"

# Verify
git --version
```

Then retry: `.\scripts\setup_windows.ps1 -SkipInstall`

---

### Visual Studio Build Tools not installing

**Error:**
```
winget install Microsoft.VisualStudio.2022.BuildTools exited with error
```

**Solution:**

1. Download manually from:
   https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022

2. Run the installer
3. Select **"Desktop development with C++"** workload
4. Complete installation
5. Close and reopen PowerShell
6. Retry: `.\scripts\setup_windows.ps1 -SkipInstall`

---

### Rust Installation Fails

**Error:**
```
The Rust toolchain could not be installed
```

**Solution:**

Download rustup manually:

```powershell
# Download rustup-init.exe
Invoke-WebRequest `
    -Uri "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe" `
    -OutFile "$env:TEMP\rustup-init.exe"

# Run installer
& "$env:TEMP\rustup-init.exe" -y `
    --default-toolchain stable `
    --default-host x86_64-pc-windows-msvc `
    --no-modify-path

# Add to PATH manually
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"

# Verify
cargo --version
rustc --version
```

---

## Build Errors

### PJSIP Build: "MSBuild not found"

**Error:**
```
MSBuild not found. Install Visual Studio 2022 Build Tools with C++ Desktop workload.
```

**Solution:**

1. Verify VS Build Tools installed:
   ```powershell
   ls "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild"
   ```

2. If missing, download and install from:
   https://visualstudio.microsoft.com/downloads/

3. Ensure **"Desktop development with C++"** workload is selected:
   - Run Visual Studio Installer
   - Click **Modify** on BuildTools entry
   - Check **"Desktop development with C++"**
   - Click **Modify** to apply

4. Retry: `.\scripts\build_pjsip.ps1`

---

### PJSIP Build: "No Release *.lib files found"

**Error:**
```
FAIL] No Release *.lib files found under engine_pjsip\pjproject
```

**Solution:**

Clean and rebuild:

```powershell
# Remove old build artifacts
Remove-Item "engine_pjsip\pjproject\x64" -Recurse -Force -ErrorAction SilentlyContinue

# Force a fresh build
.\scripts\build_pjsip.ps1

# Check the MSBuild output above for actual errors
```

If MSBuild still fails, check:

1. Pjproject source is present:
   ```powershell
   Test-Path "engine_pjsip\pjproject\pjlib"
   ```

2. VS Build Tools C++ workload installed (see above)

3. Look for detailed MSBuild errors in the output

---

### Rust Build: "PJSIP build outputs not found"

**Error:**
```
ERROR: PJSIP build outputs not found at:
  - engine_pjsip\build\out\include
  - engine_pjsip\build\out\lib
```

**PJSIP is required.** Build it before compiling the Rust core.

**Solution:**

```powershell
.\scripts\build_pjsip.ps1   # Build PJSIP first
.\scripts\build_core.ps1    # Then rebuild Rust
```

---

### Rust Build: "LNK1120: unresolved externals"

**Error:**
```
LNK1120: 5 unresolved externals in "voip_core.dll"
link.exe failed with code 1181
```

**Solution:**

This means the Rust `build.rs` can't find PJSIP libs. Either:

1. **Build PJSIP first**:
   ```powershell
   .\scripts\build_pjsip.ps1
   ```

2. **Or, set environment variables explicitly**:
   ```powershell
   $env:PJSIP_LIB_DIR = "C:\Users\YourName\Downloads\PacketDial\engine_pjsip\build\out\lib"
   $env:PJSIP_INCLUDE_DIR = "C:\Users\YourName\Downloads\PacketDial\engine_pjsip\build\out\include"
   ```

---

### Rust Build: "cc crate: compiler not found"

**Error:**
```
error: Microsoft Visual C++ 12.0 or greater is required.
```

**Solution:**

Install Visual Studio Build Tools with C++ support (see PJSIP build errors above).

---

### Flutter Build: "flutter command not found"

**Error:**
```
flutter: The term 'flutter' is not recognized
```

**Solution:**

1. Verify Flutter SDK installed:
   ```powershell
   ls "$env:USERPROFILE\flutter"
   ```

2. If missing, re-run setup:
   ```powershell
   .\scripts\setup_windows.ps1
   ```

3. Manually, if flutter installed:
   ```powershell
   $env:PATH = "$env:USERPROFILE\flutter\bin;$env:PATH"
   flutter --version
   ```

---

### Flutter: "Windows desktop not enabled"

**Error:**
```
The "windows" platform is not available for this project.
```

**Solution:**

```powershell
flutter config --enable-windows-desktop
flutter clean
flutter pub get
flutter build windows
```

---

## Runtime Problems

### App crashes immediately: "DLL not found"

**Error:**
```
The code execution cannot proceed because voip_core.dll was not found.
```

**Solution:**

Ensure the DLL is in the same directory as `PacketDial.exe`:

```powershell
# Check if DLL exists
ls "app_flutter\build\windows\x64\runner\Release\voip_core.dll"

# If missing, build it
.\scripts\build_core.ps1

# Or, copy manually
Copy-Item "core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll" `
          "app_flutter\build\windows\x64\runner\Release\"
```

---

### App crashes: "FFI signature mismatch"

**Error:**
```
Argument type mismatch in FFI: expected Pointer<...>, got int
```

**Solution:**

Dart FFI types must match Rust C signatures exactly. Check:

1. **Dart FFI definition** (`engine_channel.dart`):
   ```dart
   typedef foo_t = Pointer<Utf8> Function(Pointer<Utf8>);
   ```

2. **Rust export** (`lib.rs`):
   ```rust
   #[no_mangle]
   pub extern "C" fn foo(arg: *const c_char) -> *const c_char { /* ... */ }
   ```

Must match:
- Return type: `Pointer<Utf8>` ↔ `*const c_char`
- Arguments: `Pointer<Utf8>` ↔ `*const c_char`
- No `&` or `String` in Rust FFI (use raw pointers)

See `docs/FFI_API.md` for correct signatures.

---

### Hot-reload not working

**Error:**
```
Failed to hot reload: ... invalid version of file
```

**Solution:**

Press `R` instead (hot-restart) to rebuild Rust code:

```
Press 'R' in the Flutter terminal
  ↓
Rust code recompiles
  ↓
DLL reloaded
  ↓
App hot-reloads
```

If still broken:

```powershell
# Exit Flutter (press 'q')
# Then restart:
.\scripts\run_app.ps1
```

---

## DLL & FFI Issues

### "PacketDial.exe" *dependency was not found**

**At startup:**
```
The code execution cannot proceed because voip_core.dll was not found.
```

**Solution:**

See [DLL not found](#app-crashes-immediately-dll-not-found) above.

---

### File lock on voip_core.dll (can't copy)

**Error:**
```
The file "voip_core.dll" is locked by another process.
```

**Solution:**

Close the running PacketDial process:

```powershell
# Force-terminate the process
Stop-Process -Name "PacketDial" -Force

# Or, use `run_app.ps1` which automatically handles this:
.\scripts\run_app.ps1
```

---

### DLL "entry point not found"

**Error:**
```
The procedure entry point <function_name> could not be located in the dynamic link library
```

**Solution:**

1. Verify the export exists in Rust code:
   ```rust
   #[no_mangle]
   pub extern "C" fn my_function() -> i32 { /* ... */ }
   ```

2. Export as C symbol (not Rust mangled name)
3. Rebuild: `cargo build --release --target x86_64-pc-windows-msvc`
4. Verify with `dumpbin`:
   ```powershell
   dumpbin /exports "core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll"
   ```

---

## Windows-Specific Issues

### "Path too long" errors (MAX_PATH limits)

**Error:**
```
The filename or extension is too long.
error: cannot find <long-nested-path>
```

**Solution:**

The setup script automatically maps the repository to `X:\` to avoid this. If issues persist:

```powershell
# Check if mapping exists
subst

# If not, create it:
subst X: "<full-path-to-PacketDial>"
Set-Location X:\

# Remove old mapping if needed:
subst X: /d
subst X: "<full-path-to-PacketDial>"
```

**Workaround:** Clone/extract to a short path:
```powershell
# Bad (too long):
C:\Users\vm_user\Downloads\deeply\nested\PacketDial

# Good (short):
C:\PacketDial
or
D:\w\PacketDial
```

---

### "Long paths not enabled" (Windows 10)

**Error:**
```
The filename or extension is too long.
```

**Solution:**

```powershell
# Enable long paths in registry
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
                 -Name LongPathsEnabled -Value 1

# Enable for Git globally
git config --system core.longpaths true

# Reboot may be required
Restart-Computer
```

---

### "Registry permission denied"

**Solution:**

Run PowerShell **as Administrator**:

1. Right-click **PowerShell** → **Run as administrator**
2. Retry: `.\scripts\setup_windows.ps1`

---

## Performance & Optimization

### Builds are very slow

| Phase | Typical Time | Optimization |
|-------|--------------|----------------|
| PJSIP | 5–20 min | Run once; cached thereafter |
| Rust (debug) | 30–60 sec | Fast; suitable for hot-reload |
| Rust (release) | 1–3 min | Enable LTO for smaller binary (adds time) |
| Flutter | varies | Run `flutter clean` only if needed |

**Tips:**

```powershell
# Use debug mode for development (much faster)
cargo build --target x86_64-pc-windows-msvc

# Parallel jobs (all CPU cores by default, can limit if needed)
.\scripts\build_pjsip.ps1 -Jobs 4

# Incremental Rust builds (only recompile changed files)
# Automatic in cargo (no need to do anything)

# Flutter: skip cleaning unless necessary
flutter pub get
flutter build windows --release
# Don't use "flutter clean" unless code is corrupted
```

---

### Memory usage is high

If the Rust DLL is using excessive memory:

1. Check for memory leaks in Rust code (use `valgrind` or Rust leak detectors)
2. Ensure strings are properly freed in FFI calls
3. Monitor with Windows Task Manager

---

### App is laggy / unresponsive

**Solution:**

1. Run release build instead of debug:
   ```powershell
   flutter build windows --release
   ```

2. Check CPU usage (Task Manager)

3. Profile Flutter app:
   ```
   Press 'p' in Flutter terminal to show performance overlay
   ```

---

## Getting Help

If issues persist:

1. Check the [docs/](../) folder for component-specific guides
2. Visit the [PacketDial GitHub Issues](https://github.com/md-riaz/PacketDial/issues)
3. Enable verbose logging:
   ```powershell
   flutter run -d windows -v    # Verbose Flutter output
   cargo build -vv              # Verbose Rust output
   ```

4. Collect diagnostic bundle from the app's **Diagnostics** screen

---

## See Also

- [Quick Start](quickstart.md) — Get up and running fast
- [Windows Setup Guide](windows_setup_guide.md) — Full installation guide
- [Developer Workflow](dev-workflow.md) — Hot-reload and debugging

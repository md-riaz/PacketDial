# Windows Build & CI

> **For a complete step-by-step guide and the one-click setup script, see
> [docs/windows_setup_guide.md](windows_setup_guide.md).**

## Requirements

- Visual Studio Build Tools 2022 (Desktop development with C++ workload)
- Rust stable toolchain (`rustup target add x86_64-pc-windows-msvc`)
- Flutter SDK 3.41.2 stable (`flutter config --enable-windows-desktop`)
- Git

---

## Quick build (automated)

```powershell
# From an elevated PowerShell at the repo root:
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\setup_windows.ps1
```

---

## Manual build steps

```powershell
# 1. Enable long paths
git config --system core.longpaths true

# 2. Map to short path (avoids MAX_PATH)
subst X: "$PWD"
X:

# 3. Fetch and build PJSIP (one-time, ~10-20 min on first run)
.\scripts\fetch_pjsip.ps1
.\scripts\build_pjsip.ps1 -SkipFetch

# 4. Build Rust core (links against built PJSIP)
$env:PJSIP_LIB_DIR     = "$PWD\engine_pjsip\build\out\lib"
$env:PJSIP_INCLUDE_DIR = "$PWD\engine_pjsip\build\out\include"
cd core_rust
cargo build --release --target x86_64-pc-windows-msvc
cd ..

# 5. Build Flutter app
cd app_flutter
flutter pub get
flutter clean
flutter build windows --release
cd ..

# 6. Copy DLL and package
Copy-Item core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll `
          app_flutter\build\windows\x64\runner\Release\
.\scripts\package.ps1
```

Output: `dist\PacketDial-windows-x64.zip`

---

## GitHub Actions Pipeline

Jobs:
- Rust tests + `cargo build --release --target x86_64-pc-windows-msvc`
- Flutter build (`flutter build windows --release`)
- Package artifact (`scripts\package.ps1`)

Artifacts:
- `dist\PacketDial-windows-x64.zip` (executable + Flutter runtime + DLL)
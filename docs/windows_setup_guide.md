# Windows Setup Guide — PacketDial

This guide walks you through building **PacketDial** on a fresh Windows 10 or Windows 11
machine, even without prior developer experience.  
The automated script `scripts/setup_windows.ps1` mirrors the exact steps that the
GitHub Actions CI pipeline performs.

---

## Table of contents

1. [What you need](#1-what-you-need)
2. [Clone the repository](#2-clone-the-repository)
3. [Run the setup script (recommended)](#3-run-the-setup-script-recommended)
4. [What the script does — step by step](#4-what-the-script-does--step-by-step)
5. [Manual setup (alternative)](#5-manual-setup-alternative)
6. [Build output](#6-build-output)
7. [Troubleshooting](#7-troubleshooting)
8. [Frequently asked questions](#8-frequently-asked-questions)

---

## 1. What you need

| Requirement | Notes |
|---|---|
| Windows 10 (version 1809 or later) or Windows 11 | 64-bit |
| At least **10 GB** free disk space | Rust + Flutter toolchains are large |
| Internet connection | Installer downloads happen automatically |
| Administrator access | Required to install tools and enable long paths |

> **Windows Package Manager (winget)** must be available.  
> On Windows 10 it ships with the *App Installer* — install it from the Microsoft Store if needed:  
> <https://aka.ms/getwinget>

---

## 2. Clone the repository

If you already have **Git** installed open a terminal and run:

```powershell
git clone --recurse-submodules https://github.com/md-riaz/PacketDial
cd PacketDial
```

If you do **not** have Git yet, the setup script installs it for you — but you will need to
download the repository as a ZIP from GitHub first and extract it:

1. Go to <https://github.com/md-riaz/PacketDial>
2. Click **Code → Download ZIP**
3. Extract the ZIP to a short path such as `C:\PacketDial`

> **Tip — use a short path.**  
> Windows historically limits file paths to 260 characters (MAX_PATH).  
> The script works around this limitation automatically, but cloning/extracting to a
> short root like `C:\w\PacketDial` or `C:\PacketDial` avoids potential issues.

---

## 3. Run the setup script (recommended)

1. Open the **Start Menu**, search for **PowerShell**.
2. Right-click **Windows PowerShell** and choose **Run as administrator**.
3. In the blue PowerShell window, navigate to the repository:

   ```powershell
   cd C:\PacketDial        # adjust to wherever you placed the repo
   ```

4. Allow the script to run (one-time) and start it:

   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\scripts\setup_windows.ps1
   ```

The script prints a coloured progress log.  
Total time on a first run is roughly **20–40 minutes** (dominated by VS Build Tools and
Rust/Flutter downloads).

### Script flags

| Flag | Effect |
|---|---|
| `-SkipInstall` | Skip installing tools (use when tools are already installed) |
| `-SkipBuild` | Install tools only; do not build the app |
| `-FlutterVersion <ver>` | Override the Flutter version (default: `3.41.2`) |

Example — re-build after a code change without reinstalling tools:

```powershell
.\scripts\setup_windows.ps1 -SkipInstall
```

---

## 4. What the script does — step by step

The script replicates the GitHub Actions CI pipeline exactly.

### Step 1 — Enable long-path support
Windows limits paths to 260 characters by default.  
The script sets the registry key `LongPathsEnabled = 1` and configures Git to allow long
paths (`git config --system core.longpaths true`).

### Step 2 — Install prerequisites

All tools are installed using **winget** (Windows Package Manager):

| Tool | winget ID | Why it is needed |
|---|---|---|
| Git | `Git.Git` | Source control |
| Visual Studio Build Tools 2022 (C++ workload) | `Microsoft.VisualStudio.2022.BuildTools` | Compiles Rust (MSVC toolchain) and Flutter's native code |
| Rust via rustup | `Rustlang.Rustup` | Builds `voip_core.dll` |
| Flutter SDK | `Google.FlutterSDK` | Builds the desktop UI |

> If the **Google.FlutterSDK** winget package is unavailable the script falls back to
> downloading Flutter `3.41.2` directly from storage.googleapis.com — matching the CI
> version exactly.

### Step 3 — Map repository to a short drive letter (X:)

```powershell
subst X: <repo-root>
```

This maps the repository to `X:\` so that nested build paths stay within the 260-character
limit.  All subsequent build commands run from `X:\`.

### Step 4 — Fetch and build PJSIP

```powershell
.\scripts\fetch_pjsip.ps1       # Download pjproject 2.14.1 (~20 MB zip)
.\scripts\build_pjsip.ps1 -SkipFetch  # Build with msbuild (~10-20 min)
```

Output: `engine_pjsip\build\out\lib\` and `engine_pjsip\build\out\include\`

This step is skipped automatically on repeat runs when the build stamp file already exists.

### Step 5 — Build Rust core

```powershell
$env:PJSIP_LIB_DIR     = "$PWD\engine_pjsip\build\out\lib"
$env:PJSIP_INCLUDE_DIR = "$PWD\engine_pjsip\build\out\include"
cd core_rust
cargo build --release --target x86_64-pc-windows-msvc
```

Output: `core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll`

### Step 5 — Fetch Flutter packages

```powershell
cd app_flutter
flutter pub get
```

### Step 6 — Build Flutter Windows app

```powershell
cd app_flutter
flutter clean
flutter build windows --release
```

Output: `app_flutter\build\windows\x64\runner\Release\`  
(contains `PacketDial.exe`, `flutter_windows.dll`, `icudtl.dat`, `data\flutter_assets\`)

### Step 7 — Copy voip_core.dll into the Flutter output

```powershell
Copy-Item core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll `
          app_flutter\build\windows\x64\runner\Release\
```

### Step 8 — Package

```powershell
.\scripts\package.ps1
```

Output: `dist\PacketDial-windows-x64.zip`

---

## 5. Manual setup (alternative)

If you prefer to install tools yourself or if the script fails at a particular step, follow
the manual steps below.

### 5.1 Visual Studio Build Tools 2022

1. Download from <https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022>
2. Run the installer and select the **Desktop development with C++** workload.
3. Click **Install** and wait for it to finish.

### 5.2 Git

Download from <https://git-scm.com/download/win> and install with default settings.

### 5.3 Rust

1. Download `rustup-init.exe` from <https://rustup.rs>.
2. Run it and choose option **1** (default install).
3. After installation, open a new terminal and run:

   ```powershell
   rustup target add x86_64-pc-windows-msvc
   ```

### 5.4 Flutter

1. Download Flutter 3.41.2 (stable) from:  
   <https://docs.flutter.dev/get-started/install/windows/desktop>
2. Extract the ZIP to `C:\flutter`.
3. Add `C:\flutter\bin` to your **PATH**:
   - Open **System Properties → Environment Variables**
   - Under *User variables*, select `Path` → **Edit** → **New** → `C:\flutter\bin`
4. Open a new terminal and run:

   ```powershell
   flutter config --enable-windows-desktop
   flutter doctor    # resolve any remaining issues it reports
   ```

### 5.5 Build commands (manual)

Run all commands from the repository root in an elevated PowerShell:

```powershell
# Enable long paths
git config --system core.longpaths true
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1

# Map to short path
subst X: "$PWD"
X:

# Build Rust core
cd core_rust
cargo build --release --target x86_64-pc-windows-msvc
cd ..

# Flutter
cd app_flutter
flutter pub get
flutter clean
flutter build windows --release
cd ..

# Copy DLL into Flutter output
Copy-Item core_rust\target\x86_64-pc-windows-msvc\release\voip_core.dll `
          app_flutter\build\windows\x64\runner\Release\

# Package
.\scripts\package.ps1
```

---

## 6. Build output

After a successful build you will find:

```
dist\
└── PacketDial-windows-x64.zip    ← distributable package
```

Unzip it anywhere and double-click **PacketDial.exe** to launch the app.

The ZIP contains:

```
PacketDial.exe
flutter_windows.dll
icudtl.dat
voip_core.dll          (present when PJSIP integration is enabled)
data\
└── flutter_assets\
version.json
```

---

## 7. Troubleshooting

### "This script must be run as Administrator"

Right-click **Windows PowerShell** in the Start Menu and choose
**Run as administrator** before running the script.

### "execution of scripts is disabled on this system"

Run this once at the top of your elevated PowerShell session:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### winget not found

Install the **App Installer** from the Microsoft Store:  
<https://aka.ms/getwinget>

Then close and reopen PowerShell.

### "error: linker `link.exe` not found"

The Visual Studio C++ Build Tools are not installed or not on PATH.  
Re-run the script (or install the VS Build Tools manually per §5.1) and then open a new
terminal — Visual Studio's environment variables are only added to **new** sessions.

### Flutter build fails with "CMake Error"

Make sure the **Desktop development with C++** workload is installed in Visual Studio Build
Tools (the *C++ CMake tools for Windows* component is included in the recommended install).

### Path-length errors (`filename too long`, `ENAMETOOLONG`)

Run the script from a short path (e.g. `C:\PacketDial`) and ensure the elevated PowerShell
is used so the registry `LongPathsEnabled` key can be set.

### The X: drive is already in use

The script calls `subst X: /d` first to clear any previous mapping.  
If drive `X:` is permanently assigned by your system, edit `setup_windows.ps1` and change
every occurrence of `X:` to a free drive letter (e.g. `Y:`).

### voip_core.dll is missing from the package

PJSIP integration is still in progress (Milestone M7).  
The app will run without the DLL — the warning is informational only.

---

## 8. Frequently asked questions

**Q: Does this work on Windows 10 without any Windows updates?**  
A: Windows 10 version 1809 (October 2018 Update) or later is required.  
Long-path support and winget require at least Windows 10 1809.

**Q: Can I use Visual Studio 2019 instead of 2022?**  
A: Yes, but the script installs 2022 Build Tools.  
If 2019 is already installed with the C++ workload, you can pass `-SkipInstall`
and the build will use whichever MSVC version is on PATH.

**Q: Do I need to re-run the setup script after updating the code?**  
A: No.  After the first full run, use `-SkipInstall` to skip the tool-installation phase:

```powershell
.\scripts\setup_windows.ps1 -SkipInstall
```

**Q: How do I run the app in development mode (hot reload)?**  
After tools are installed, run:

```powershell
.\scripts\run_app.ps1
```

**Q: Where are the CI workflow files?**  
See `.github/workflows/windows-ci.yml` and `.github/workflows/release.yml`.

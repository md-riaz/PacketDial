# PacketDial Quick Start (5 minutes)

**TL;DR:** One command to build and run PacketDial on Windows 10/11.

---

## Prerequisites

- Windows 10 (build 1809+) or Windows 11, 64-bit
- Administrator access to PowerShell
- 10+ GB free disk space
- Internet connection (for tool downloads only)

---

## Build & Run (One-Click)

Open **PowerShell as Administrator** and run:

```powershell
git clone https://github.com/md-riaz/PacketDial
cd PacketDial
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\setup_windows.ps1
```

The script:
1. Installs Git, Visual Studio Build Tools, Rust, and Flutter (if not present)
2. Builds PJSIP, Rust core, and Flutter app
3. Creates `dist\PacketDial-windows-x64.zip`

**Total time:** 20–40 minutes on first run.

---

## Develop Locally (Hot-Reload)

If tools are already installed and you just want to code:

```powershell
.\scripts\run_app.ps1
```

This:
- Rebuilds `voip_core.dll` (debug mode, ~30 seconds)
- Launches Flutter with hot-reload enabled
- Press `r` to hot-reload Dart code instantly
- Press `R` to restart (rebuilds Rust + reloads)

---

## Next Steps

| Goal | Command |
|------|---------|
| **Rebuild after code changes** | `.\scripts\setup_windows.ps1 -SkipInstall` |
| **Build release DLL only** | `.\scripts\build_core.ps1` |
| **Build debug DLL only** | `.\scripts\build_core_debug.ps1` |
| **Rebuild PJSIP (rarely needed)** | `.\scripts\build_pjsip.ps1` |
| **Create release ZIP** | `.\scripts\package.ps1` |

---

## Troubleshooting

- **"Path too long" errors?**  
  Script handles this automatically via `subst X:`. If issues persist, see [troubleshooting.md](troubleshooting.md).

- **"PJSIP build failed"?**  
  PJSIP is optional. The app runs as a stub SIP client without it.

- **PowerShell script execution blocked?**  
  Run: `Set-ExecutionPolicy Bypass -Scope Process -Force`

For more help, see:
- [Full Windows Setup Guide](windows_setup_guide.md)
- [Developer Workflow](dev-workflow.md)
- [Troubleshooting Guide](troubleshooting.md)

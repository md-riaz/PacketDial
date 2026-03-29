# GitHub Release Guide

## Creating a Release

### Option 1: Manual Workflow Dispatch (Recommended)

1. **Go to Actions tab** on GitHub
2. **Select "release" workflow**
3. **Click "Run workflow"**
4. **Enter version number** (e.g., `1.0.0`)
5. **Click "Run workflow"**

The workflow will:
- ✅ Build PJSIP
- ✅ Build Rust core
- ✅ Build Flutter app
- ✅ Create portable ZIP
- ✅ Create installer EXE
- ✅ Create GitHub Release with both files

### Option 2: Git Tag (Automatic)

```bash
# Create and push a tag
git tag v1.0.0
git push origin v1.0.0
```

> Note: Tag-based releases require updating the workflow trigger.

---

## Release Artifacts

After the workflow completes, the release will include:

### 1. Portable ZIP
**File:** `PacketDial-{version}-Portable.zip`

**Contents:**
```
PacketDial/
├── PacketDial.exe
├── voip_core.dll
├── flutter_windows.dll
├── icudtl.dat
├── data/
├── README.txt
├── UNINSTALL.bat
└── CreateShortcut.bat
```

**Size:** ~50-80 MB

### 2. Windows Installer
**File:** `PacketDial-Setup-{version}.exe`

**Features:**
- Professional setup wizard
- Installs to `C:\Program Files\PacketDial`
- Start Menu shortcut
- Desktop shortcut (optional)
- Uninstaller in Control Panel

**Size:** ~30-50 MB

---

## Release Notes

The workflow automatically generates release notes from:
- Git commit messages since last release
- Pull request titles and descriptions
- Manual additions in the workflow file

---

## Pre-Release Checklist

Before creating a release:

- [ ] All tests pass (`cargo test` + `flutter test`)
- [ ] Flutter analyze shows no errors
- [ ] Version number updated in `app_flutter/pubspec.yaml`
- [ ] Version number updated in `core_rust/Cargo.toml`
- [ ] CHANGELOG.md updated
- [ ] Documentation updated
- [ ] Tested on clean Windows 10/11 VM

---

## Post-Release Tasks

After release is published:

1. **Test Installation**
   - Download installer
   - Install on clean VM
   - Verify all features work

2. **Test Portable**
   - Download ZIP
   - Extract and run
   - Verify functionality

3. **Update Documentation**
   - Update README if needed
   - Update FEATURES.md
   - Update quickstart guide

4. **Announce Release**
   - GitHub Discussions
   - Social media
   - User mailing list

---

## Troubleshooting

### Workflow Fails

**Error: PJSIP build failed**
- Check `engine_pjsip/pjproject_config_site.h`
- Verify submodules are initialized: `git submodule update --init --recursive`

**Error: Flutter build failed**
- Check Flutter version in `build-windows/action.yml`
- Verify `flutter doctor` passes

**Error: Inno Setup not found**
- Installer step will be skipped
- Portable ZIP will still be created
- Install Inno Setup for full release

### Release Not Created

**Check permissions:**
- Workflow needs `contents: write` permission
- GitHub token must have release access

**Check workflow logs:**
- Go to Actions tab
- Find failed workflow run
- Review error messages

---

## Version Numbering

PacketDial uses semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR** (1.0.0) - Breaking changes
- **MINOR** (1.1.0) - New features (backward compatible)
- **PATCH** (1.0.1) - Bug fixes (backward compatible)

**Pre-release examples:**
- `1.0.0-beta.1`
- `1.0.0-rc.1`
- `1.0.0-alpha.2`

---

## Example Release Commands

```bash
# Local testing
.\scripts\build_all.ps1 -Version 1.0.0

# Create release
git tag v1.0.0
git push origin v1.0.0

# Or use workflow dispatch (recommended)
# Go to Actions → release → Run workflow
```

---

**PacketDial Release System**  
Last updated: March 2026

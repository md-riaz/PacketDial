# Windows Build & CI

## Requirements

- Visual Studio Build Tools
- Rust stable toolchain
- Flutter SDK
- Git

---

## Build Steps

1. Build PJSIP static libraries
2. cargo build --release
3. flutter build windows

---

## GitHub Actions Pipeline

Jobs:
- Build PJSIP
- Rust tests + clippy
- Flutter build
- Package artifacts

Artifacts:
- Executable
- Debug symbols
- Version file
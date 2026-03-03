# PJSIP Engine

pjproject **2.14.1** source code is committed directly under:

```
engine_pjsip/pjproject/
```

No download or submodule initialisation is required — the source is part of the
repository and available immediately after a plain `git clone`.

Build PJSIP for Windows x64 (one-time, ~10-20 min):

```powershell
.\scripts\build_pjsip.ps1
```

This produces:
- `engine_pjsip/build/out/include/`  — headers for the Rust core
- `engine_pjsip/build/out/lib/`      — static libraries for linking

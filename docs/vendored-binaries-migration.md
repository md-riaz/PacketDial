# Migrating to Vendored Binaries (Skip Source Build)

This document explains how to strip the PJSIP source tree from the repo and rely
solely on the pre-compiled artifacts already committed under
`engine_pjsip/build/out/`. After this migration CI no longer builds PJSIP from
source — it just compiles the Rust core and Flutter app.

---

## Background

Currently the repo contains the full pjproject source tree
(`engine_pjsip/pjproject/`, ~65 MB). CI builds it on every cache miss.

The compiled outputs (`out/include/` headers + `out/lib/*.lib` files) are
**already committed** and are everything the Rust build actually needs:

- `core_rust/src/shim/pjsip_shim.c` only includes `<pjsua-lib/pjsua.h>` and
  `<pjmedia/audiodev.h>` — both present in `out/include/`.
- `core_rust/build.rs` links every `*.lib` found in `out/lib/` — all 23 libs
  are committed there.
- OpenSSL (`libssl.lib`, `libcrypto.lib`) comes from vcpkg at link time, not
  from the PJSIP build.

So the source tree is only needed when you want to **rebuild PJSIP itself**
(version upgrade, config change, new codec). For day-to-day development it is
dead weight.

---

## What Changes

| Before | After |
|--------|-------|
| `engine_pjsip/pjproject/` (~65 MB source) in git | Deleted from git tracking |
| CI runs `scripts/build_pjsip.ps1` (~10–20 min) | CI skips PJSIP build entirely |
| PJSIP cache step in CI | Removed |
| `scripts/build_pjsip.ps1` | Kept locally for when you need to rebuild |

`engine_pjsip/build/out/` (headers + libs) stays committed and becomes the
sole source of truth for the PJSIP ABI the project is built against.

---

## Migration Steps

### 1. Remove the source tree from git tracking

```powershell
# From repo root
git rm -r --cached engine_pjsip/pjproject
git rm --cached engine_pjsip/pjproject_config_site.h   # optional — see note below
```

> `pjproject_config_site.h` documents the compile-time flags used to produce
> the committed `.lib` files. It is worth keeping as documentation even after
> the source is gone. Only remove it if you find it confusing.

### 2. Add the source tree to .gitignore

Add to `.gitignore`:

```
# PJSIP source tree — not needed when using pre-compiled artifacts
engine_pjsip/pjproject/
```

### 3. Update the CI action

In `.github/actions/build-windows/action.yml` remove (or comment out) these
three steps:

```yaml
# DELETE these steps:
- name: Cache PJSIP build output
  ...

- name: Clean stale PJSIP build artifacts
  ...

- name: Build pjproject (Release x64)
  if: steps.cache-pjsip.outputs.cache-hit != 'true'
  ...
```

The `PJSIP_LIB_DIR` / `PJSIP_INCLUDE_DIR` env vars on the cargo steps already
point at `X:\engine_pjsip\build\out\{lib,include}` — no change needed there.

### 4. Commit

```powershell
git add .gitignore .github/actions/build-windows/action.yml
git commit -m "chore: remove pjproject source tree, use pre-compiled artifacts"
```

The `engine_pjsip/pjproject/` directory can be deleted from disk after the
commit, or left in place (it will just be untracked).

---

## Updating PJSIP in the Future

When you need a new PJSIP version or want to change `pjproject_config_site.h`:

1. Restore the source tree locally (clone pjproject or `git stash pop` if you
   stashed it):

   ```powershell
   git clone --depth 1 https://github.com/pjsip/pjproject engine_pjsip/pjproject
   # or check out the specific tag you want
   ```

2. Copy your config file into place:

   ```powershell
   Copy-Item engine_pjsip/pjproject_config_site.h `
             engine_pjsip/pjproject/pjlib/include/pj/config_site.h
   ```

3. Build:

   ```powershell
   .\scripts\build_pjsip.ps1
   ```

4. Verify the outputs look correct:

   ```powershell
   Get-ChildItem engine_pjsip/build/out/lib/*.lib | Measure-Object | Select-Object Count
   # expect 23 files
   ```

5. Commit the updated `out/` artifacts:

   ```powershell
   git add engine_pjsip/build/out/
   git commit -m "chore: update PJSIP artifacts to vX.Y.Z"
   ```

6. Remove the source tree again (step 1 of the migration above) and push.

---

## What Files Must Stay in `engine_pjsip/build/out/`

These are the files the build actually consumes. Do not gitignore them.

**Headers (`out/include/`)** — all subdirectories:

```
pj/           pjlib-util/       pjmedia/          pjmedia-audiodev/
pjmedia-codec/  pjmedia-videodev/  pjnath/         pjsip/
pjsip-simple/   pjsip-ua/          pjsua-lib/      pjsua2/
pj++/
```

Plus the top-level umbrella headers (`pjlib.h`, `pjsip.h`, `pjmedia.h`, etc.).

**Libs (`out/lib/`)** — all 23 `.lib` files:

```
libbaseclasses-x86_64-x64-vc14-Release.lib
libg7221codec-x86_64-x64-vc14-Release.lib
libgsmcodec-x86_64-x64-vc14-Release.lib
libilbccodec-x86_64-x64-vc14-Release.lib
libmilenage-x86_64-x64-vc14-Release.lib
libpjproject-x86_64-x64-vc14-Release.lib
libresample-x86_64-x64-vc14-Release.lib
libspeex-x86_64-x64-vc14-Release.lib
libsrtp-x86_64-x64-vc14-Release.lib
libwebrtc-x86_64-x64-vc14-Release.lib
libyuv-x86_64-x64-vc14-Release.lib
pjlib-util-x86_64-x64-vc14-Release.lib
pjlib-x86_64-x64-vc14-Release.lib
pjmedia-audiodev-x86_64-x64-vc14-Release.lib
pjmedia-codec-x86_64-x64-vc14-Release.lib
pjmedia-videodev-x86_64-x64-vc14-Release.lib
pjmedia-x86_64-x64-vc14-Release.lib
pjnath-x86_64-x64-vc14-Release.lib
pjsip-core-x86_64-x64-vc14-Release.lib
pjsip-simple-x86_64-x64-vc14-Release.lib
pjsip-ua-x86_64-x64-vc14-Release.lib
pjsua-lib-x86_64-x64-vc14-Release.lib
pjsua2-lib-x86_64-x64-vc14-Release.lib
```

**Stamp file:** `out/pjsip_build_stamp.txt` — used by `build.rs` cache
invalidation, keep it.

---

## No Code Changes Required

`core_rust/build.rs` already supports this layout. It resolves paths in this
order:

1. `PJSIP_LIB_DIR` / `PJSIP_INCLUDE_DIR` env vars (used by CI)
2. `engine_pjsip/build/out/` relative to the workspace root (used locally)

After the migration, local `cargo build` will automatically find the committed
artifacts via path 2 — no env vars needed on a dev machine.

---

## See Also

- [PJSIP Build Guide](pjsip-build.md) — how to build PJSIP from source
- [Rust Core Build Guide](rust-core.md) — how `build.rs` links against PJSIP

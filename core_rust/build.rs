use std::env;
use std::path::PathBuf;

fn main() {
    // -----------------------------------------------------------------------
    // Locate PJSIP libs and headers.
    //
    // Resolution order (first match wins):
    //   1. PJSIP_LIB_DIR / PJSIP_INCLUDE_DIR environment variables
    //      (set manually or by CI before invoking cargo).
    //   2. engine_pjsip/build/out/ relative to the workspace root
    //      (produced by scripts/build_pjsip.ps1).
    //
    // PJSIP is required — the build will fail if libs are not found.
    // -----------------------------------------------------------------------

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    // core_rust/ → repo root is one level up
    let repo_root = manifest_dir
        .parent()
        .expect("CARGO_MANIFEST_DIR has no parent");

    // --- Resolve lib and include paths --------------------------------------

    let env_lib_dir = env::var("PJSIP_LIB_DIR").ok().map(PathBuf::from);
    let env_include_dir = env::var("PJSIP_INCLUDE_DIR").ok().map(PathBuf::from);

    let auto_out = repo_root.join("engine_pjsip").join("build").join("out");
    let auto_lib = auto_out.join("lib");
    let auto_inc = auto_out.join("include");

    let lib_dir = env_lib_dir.filter(|p| p.is_dir()).or_else(|| {
        if auto_lib.is_dir() {
            Some(auto_lib.clone())
        } else {
            None
        }
    });

    let include_dir = env_include_dir.filter(|p| p.is_dir()).or_else(|| {
        if auto_inc.is_dir() {
            Some(auto_inc.clone())
        } else {
            None
        }
    });

    // Validate that the resolved lib dir actually contains .lib files.
    // If the stamp exists but libs are missing (e.g. partial build), emit a
    // clear warning rather than silently producing a link failure downstream.
    let lib_dir = lib_dir.and_then(|p| {
        let has_libs = std::fs::read_dir(&p).ok().is_some_and(|d| {
            d.flatten()
                .any(|e| e.path().extension().and_then(|x| x.to_str()) == Some("lib"))
        });
        if has_libs {
            Some(p)
        } else {
            println!(
                "cargo:warning=PJSIP lib dir exists ({}) but contains no .lib files",
                p.display()
            );
            panic!(
                "PJSIP lib dir exists ({}) but contains no .lib files. \
                 Run scripts/build_pjsip.ps1 to build PJSIP.",
                p.display()
            );
        }
    });

    // --- Emit cargo directives if PJSIP is available ------------------------

    if let Some(lib) = &lib_dir {
        println!("cargo:rustc-link-search=native={}", lib.display());

        // Link every *.lib found in the output directory.
        // pjproject names libs like: pjlib-x86_64-x64-vc14-Release.lib
        if let Ok(entries) = std::fs::read_dir(lib) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) == Some("lib") {
                    let stem = path
                        .file_stem()
                        .and_then(|s| s.to_str())
                        .unwrap_or_default();
                    // cargo:rustc-link-lib expects the base name without prefix/suffix
                    println!("cargo:rustc-link-lib=static={stem}");
                }
            }
        }

        // Windows system libs required by pjproject
        println!("cargo:rustc-link-lib=ws2_32");
        println!("cargo:rustc-link-lib=ole32");
        println!("cargo:rustc-link-lib=uuid");
        println!("cargo:rustc-link-lib=winmm");
        println!("cargo:rustc-link-lib=Avrt");

        // Signal to the rest of the crate that PJSIP is available so that
        // real SIP code paths are compiled in (M7 integration).
        println!("cargo:rustc-cfg=pjsip_available");

        println!(
            "cargo:warning=PJSIP integration: linking against libs in {}",
            lib.display()
        );
    } else {
        panic!(
            "PJSIP not found. Run scripts/build_pjsip.ps1 to build PJSIP, \
             or set PJSIP_LIB_DIR and PJSIP_INCLUDE_DIR environment variables."
        );
    }

    if let Some(inc) = &include_dir {
        println!("cargo:include={}", inc.display());
    }

    // --- Compile C shim -------------------------------------------------------
    //
    // The C shim source file at core_rust/src/shim/pjsip_shim.c is compiled and
    // linked using the cc crate. Both the shim file and the include directory
    // must exist.
    let shim_src = manifest_dir.join("src").join("shim").join("pjsip_shim.c");
    if shim_src.exists() {
        if let Some(inc) = &include_dir {
            println!("cargo:rerun-if-changed=src/shim/pjsip_shim.c");
            println!("cargo:rerun-if-changed=src/shim/pjsip_shim.h");
            cc::Build::new()
                .file(&shim_src)
                // PJSIP public headers (e.g. pjsua-lib/pjsua.h, pj/config.h)
                .include(inc)
                // shim's own header directory
                .include(manifest_dir.join("src").join("shim"))
                .opt_level(2)
                .compile("pjsip_shim");
        }
    }

    // Re-run if the stamp file or env vars change
    let stamp = auto_out.join("pjsip_build_stamp.txt");
    println!("cargo:rerun-if-changed={}", stamp.display());
    println!("cargo:rerun-if-env-changed=PJSIP_LIB_DIR");
    println!("cargo:rerun-if-env-changed=PJSIP_INCLUDE_DIR");
}

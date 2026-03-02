use std::env;
use std::path::PathBuf;

fn main() {
    // If PJSIP is not built yet, we still allow building the crate for scaffolding.
    // When linking real PJSIP libs, set env vars:
    // - PJSIP_INCLUDE_DIR
    // - PJSIP_LIB_DIR
    //
    // This build script demonstrates how you'd wire include/lib paths.
    // It does NOT compile PJSIP for you.

    let include_dir = env::var("PJSIP_INCLUDE_DIR").ok();
    let lib_dir = env::var("PJSIP_LIB_DIR").ok();

    if let Some(inc) = include_dir {
        println!("cargo:include={}", inc);
    }
    if let Some(lib) = lib_dir {
        println!("cargo:rustc-link-search=native={}", lib);

        // Typical PJSIP libs; adjust names to match your build artifacts.
        // Uncomment once you have the right .lib set in engine_pjsip/build/out/lib
        //
        // println!("cargo:rustc-link-lib=static=pjsip-core");
        // println!("cargo:rustc-link-lib=static=pjsip-ua");
        // println!("cargo:rustc-link-lib=static=pjsip-simple");
        // println!("cargo:rustc-link-lib=static=pjmedia");
        // println!("cargo:rustc-link-lib=static=pjnath");
        // println!("cargo:rustc-link-lib=static=pjlib-util");
        // println!("cargo:rustc-link-lib=static=pjlib");
    }

    // Ensure rebuild if env changes
    println!("cargo:rerun-if-env-changed=PJSIP_INCLUDE_DIR");
    println!("cargo:rerun-if-env-changed=PJSIP_LIB_DIR");

    // Optional: if you add C shim files under src/shim, compile with cc here.
    let _out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
}

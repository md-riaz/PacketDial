use once_cell::sync::OnceCell;
use std::ffi::CString;
use std::os::raw::c_char;
use std::sync::atomic::{AtomicBool, Ordering};

static INITIALIZED: AtomicBool = AtomicBool::new(false);
static VERSION: OnceCell<CString> = OnceCell::new();

#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub enum EngineErrorCode {
    Ok = 0,
    AlreadyInitialized = 1,
    NotInitialized = 2,
    InternalError = 100,
}

fn version_cstr() -> &'static CString {
    VERSION.get_or_init(|| CString::new("voip_core 0.1.0 (scaffold)").unwrap())
}

/// Initialize the engine.
/// In future milestones, this will initialize PJSIP and related subsystems.
#[no_mangle]
pub extern "C" fn engine_init() -> i32 {
    if INITIALIZED.swap(true, Ordering::SeqCst) {
        return EngineErrorCode::AlreadyInitialized as i32;
    }
    // TODO: initialize PJSIP here (pj_init, pjsua_create, etc.)
    EngineErrorCode::Ok as i32
}

/// Shutdown the engine.
#[no_mangle]
pub extern "C" fn engine_shutdown() -> i32 {
    if !INITIALIZED.swap(false, Ordering::SeqCst) {
        return EngineErrorCode::NotInitialized as i32;
    }
    // TODO: shutdown PJSIP here (pjsua_destroy, etc.)
    EngineErrorCode::Ok as i32
}

/// Returns a pointer to a static, null-terminated UTF-8 string.
/// The pointer remains valid for the lifetime of the process.
#[no_mangle]
pub extern "C" fn engine_version() -> *const c_char {
    version_cstr().as_ptr()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn init_shutdown_ok() {
        assert_eq!(engine_init(), EngineErrorCode::Ok as i32);
        assert_eq!(engine_shutdown(), EngineErrorCode::Ok as i32);
    }

    #[test]
    fn init_twice() {
        assert_eq!(engine_init(), EngineErrorCode::Ok as i32);
        assert_eq!(engine_init(), EngineErrorCode::AlreadyInitialized as i32);
        assert_eq!(engine_shutdown(), EngineErrorCode::Ok as i32);
    }
}

# Rust <-> Flutter FFI API (v0)

## C ABI
All functions use `extern "C"` and stable primitive types.

```c
// returns 0 on success, non-zero on failure
int32_t engine_init(void);

// returns 0 on success
int32_t engine_shutdown(void);

// returns pointer to a null-terminated UTF-8 string (static)
const char* engine_version(void);
```

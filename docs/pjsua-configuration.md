# PJSUA Configuration Structure

This document describes how PacketDial configures the PJSIP/PJSUA library through a structured configuration approach.

---

## Overview

PacketDial uses PJSUA-LIB, which is a high-level SIP API on top of PJSIP. The library's behavior—registration, messaging, call control—is configured through configuration structures during initialization.

Previously, these configuration parameters were hardcoded in the C shim layer. Now, they are exposed through a structured `PdConfig` type that can be populated from Rust and passed to the C shim during initialization.

---

## Configuration Structure

### PdConfig (C / Rust)

The `PdConfig` structure contains all configurable parameters for PJSUA initialization:

```c
typedef struct PdConfig {
    /* UA configuration (maps to pjsua_config) */
    const char *user_agent;       /* User-Agent header value (NULL = default) */
    const char *stun_server;      /* STUN server "host:port" (NULL = disabled) */
    int         max_calls;        /* Maximum concurrent calls (0 = default 4) */

    /* Media configuration (maps to pjsua_media_config) */
    int         clock_rate;       /* Media clock rate in Hz (0 = default 16000) */
    int         snd_clock_rate;   /* Sound device clock rate (0 = follow clock_rate) */
    int         ec_tail_len;      /* Echo cancellation tail length in ms (0 = default 200) */
    int         no_vad;           /* 1 to disable VAD, 0 to enable (default) */

    /* Logging configuration (maps to pjsua_logging_config) */
    int         log_level;        /* Log level 0-6 (0 = default 4) */
    int         console_level;    /* Console log level (0 = suppress) */
    int         msg_logging;      /* 1 to enable SIP message logging, 0 to disable */

    /* Transport configuration */
    int         udp_port;         /* UDP transport port (0 = OS-assigned) */
    int         tcp_port;         /* TCP transport port (0 = OS-assigned) */
} PdConfig;
```

---

## Configuration Parameters

### User Agent Configuration

#### `user_agent` (string, optional)
- **Purpose**: Sets the SIP User-Agent header
- **Default**: "PacketDial/0.1.0" (or PJSIP default)
- **Example**: "MyApp/1.0.0"
- **Usage**: Identifies the client to SIP servers; some providers require specific values

#### `stun_server` (string, optional)
- **Purpose**: STUN server for NAT traversal
- **Default**: NULL (disabled)
- **Format**: "hostname:port" (e.g., "stun.l.google.com:19302")
- **Usage**: Helps clients behind NAT discover their public IP address

#### `max_calls` (integer)
- **Purpose**: Maximum number of concurrent calls
- **Default**: 8
- **Range**: 1-256
- **Usage**: Limits simultaneous active calls; affects memory usage

---

### Media Configuration

#### `clock_rate` (integer, Hz)
- **Purpose**: Audio sampling rate
- **Default**: 16000 (wideband)
- **Common Values**:
  - 8000: Narrowband (G.711, basic quality)
  - 16000: Wideband (HD voice, good quality)
  - 32000: Super-wideband (excellent quality)
  - 48000: Full-band (studio quality)
- **Usage**: Higher rates provide better audio quality but use more bandwidth

#### `snd_clock_rate` (integer, Hz)
- **Purpose**: Sound device sampling rate
- **Default**: 0 (follow `clock_rate`)
- **Usage**: Set explicitly if audio hardware requires a different rate

#### `ec_tail_len` (integer, milliseconds)
- **Purpose**: Echo canceller tail length
- **Default**: 200 ms
- **Range**: 0-1000 ms
- **Guidelines**:
  - 200 ms: Typical room acoustics
  - 500 ms: Speaker-phone setups with far-end echo
  - 0: Disable echo cancellation
- **Usage**: Longer tails improve echo cancellation but increase CPU usage

#### `no_vad` (boolean)
- **Purpose**: Disable Voice Activity Detection
- **Default**: 0 (VAD enabled)
- **Usage**: VAD saves bandwidth by not transmitting silence; disable for music or continuous audio

---

### Logging Configuration

#### `log_level` (integer)
- **Purpose**: PJSIP logging verbosity
- **Default**: 4 (debug)
- **Levels**:
  - 1: Error
  - 2: Warning
  - 3: Info
  - 4: Debug
  - 5-6: Trace/Verbose
- **Usage**: Higher levels produce more diagnostic output

#### `console_level` (integer)
- **Purpose**: Console logging verbosity
- **Default**: 0 (suppress)
- **Usage**: Set to 1-6 to enable console output (not recommended for production)

#### `msg_logging` (boolean)
- **Purpose**: Enable SIP message capture
- **Default**: 1 (enabled)
- **Usage**: Captures raw SIP messages for diagnostics; disable to reduce overhead

---

### Transport Configuration

#### `udp_port` (integer)
- **Purpose**: UDP transport listening port
- **Default**: 0 (OS-assigned)
- **Range**: 0-65535
- **Usage**: Set to a fixed port for firewall rules; 0 lets OS choose an available port

#### `tcp_port` (integer)
- **Purpose**: TCP transport listening port
- **Default**: 0 (OS-assigned)
- **Range**: 0-65535
- **Usage**: TCP is more reliable but has higher latency than UDP

---

## Usage Example

### Rust Code

```rust
// Create default configuration
let mut config = PdConfig::default();

// Customize parameters
config.user_agent = CString::new("MyApp/1.0.0")?.as_ptr();
config.stun_server = CString::new("stun.l.google.com:19302")?.as_ptr();
config.max_calls = 4;
config.clock_rate = 16000;
config.ec_tail_len = 200;

// Initialize PJSUA with configuration
let rc = unsafe {
    pd_init(
        &config,
        pjsip_on_reg_state,
        pjsip_on_incoming_call,
        pjsip_on_call_state,
        pjsip_on_call_media,
        pjsip_on_log,
        pjsip_on_sip_msg,
    )
};
```

### C Code

```c
PdConfig cfg;
pd_config_default(&cfg);

// Customize parameters
cfg.user_agent = "MyApp/1.0.0";
cfg.clock_rate = 8000;  // Narrowband for compatibility
cfg.ec_tail_len = 500;  // Longer echo cancellation

// Initialize
int rc = pd_init(&cfg, on_reg, on_incoming, on_call, on_media, on_log, on_sip_msg);
```

---

## PJSUA Structure Mapping

The `PdConfig` structure maps to three PJSUA configuration structures:

### 1. pjsua_config (UA Configuration)
- `user_agent` → `ua_cfg.user_agent`
- `stun_server` → `ua_cfg.stun_srv[0]`
- `max_calls` → `ua_cfg.max_calls`

### 2. pjsua_media_config (Media Configuration)
- `clock_rate` → `med_cfg.clock_rate`
- `snd_clock_rate` → `med_cfg.snd_clock_rate`
- `ec_tail_len` → `med_cfg.ec_tail_len`
- `no_vad` → `med_cfg.no_vad`

### 3. pjsua_logging_config (Logging Configuration)
- `log_level` → `log_cfg.level`
- `console_level` → `log_cfg.console_level`
- `msg_logging` → `log_cfg.msg_logging`

---

## Benefits of Structured Configuration

1. **Flexibility**: Configuration can be changed without recompiling the C shim
2. **Testability**: Different configurations can be tested programmatically
3. **Clarity**: All configuration parameters are in one place
4. **Extensibility**: New parameters can be added to the structure without breaking existing code

---

## Why This Approach?

MicroSIP and other PJSIP-based softphones use PJSUA's configuration structures during initialization to shape how the softphone behaves. By exposing these configurations through a structured API, PacketDial maintains the same flexibility while preserving a clean Rust-to-C FFI boundary.

The Rust + base lib approach provides:
- **Type safety**: Rust's type system prevents common C errors
- **Memory safety**: Rust's ownership model prevents memory leaks
- **Concurrency**: Rust's threading model prevents race conditions
- **Maintainability**: Rust code is easier to refactor and test

This is combined with PJSIP's mature, battle-tested SIP implementation through a thin C shim layer.

---

## See Also

- [pjsip_shim.h](../core_rust/src/shim/pjsip_shim.h) - C API definition
- [pjsip_shim.c](../core_rust/src/shim/pjsip_shim.c) - C implementation
- [lib.rs](../core_rust/src/lib.rs) - Rust FFI bindings
- [PJSIP Documentation](https://docs.pjsip.org/) - Official PJSIP docs

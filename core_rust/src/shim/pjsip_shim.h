/*
 * pjsip_shim.h — PacketDial thin C wrapper around pjsua.
 *
 * All functions use C linkage and only primitive / pointer types so that
 * they can be called safely from Rust via extern "C" FFI.
 *
 * Threading model:
 *   pjsua creates its own worker threads.  The callback function pointers
 *   are set once during pd_init() before pjsua_start(), so no locking is
 *   required for the pointers themselves.  The Rust side uses Mutex-protected
 *   globals, which is safe to call from PJSIP worker threads.
 */

#ifndef PACKETDIAL_PJSIP_SHIM_H
#define PACKETDIAL_PJSIP_SHIM_H

#ifdef __cplusplus
extern "C" {
#endif

/* -----------------------------------------------------------------------
 * Callback types: called FROM PJSIP worker threads INTO Rust
 * ----------------------------------------------------------------------- */

/**
 * Registration state change.
 * @param acc_id      PJSIP account id (opaque integer)
 * @param expires     Registration expiry in seconds (0 = unregistered)
 * @param status_code SIP response code (200 = OK, 0 if unavailable)
 * @param reason      NUL-terminated status text (e.g. "OK", "Unauthorized")
 */
typedef void (*PdOnRegState)(int acc_id, int expires, int status_code,
                              const char *reason);

/**
 * Incoming call notification.
 * @param acc_id   PJSIP account id that received the call
 * @param call_id  PJSIP call id
 * @param from_uri NUL-terminated SIP URI of the caller
 */
typedef void (*PdOnIncomingCall)(int acc_id, int call_id, const char *from_uri);

/**
 * Call state change (pjsip_inv_state values):
 *   0=NULL 1=CALLING 2=INCOMING 3=EARLY 4=CONNECTING 5=CONFIRMED 6=DISCONNECTED
 * @param call_id     PJSIP call id
 * @param inv_state   pjsip_inv_state integer
 * @param status_code Last SIP status code for this state transition
 */
typedef void (*PdOnCallState)(int call_id, int inv_state, int status_code);

/**
 * Call media state change — audio is now active / held / ended.
 * @param call_id  PJSIP call id
 * @param active   1 if audio media is active (both TX and RX), 0 otherwise
 */
typedef void (*PdOnCallMedia)(int call_id, int active);

/**
 * Engine log message.
 * @param level  1=error 2=warn 3=info 4–6=debug
 * @param msg    NUL-terminated message (without trailing newline)
 */
typedef void (*PdOnLog)(int level, const char *msg);

/**
 * SIP message captured (sent or received).
 * @param call_id PJSIP call id (-1 for registration messages)
 * @param is_tx   1 = outgoing, 0 = incoming
 * @param msg     NUL-terminated raw SIP message text
 */
typedef void (*PdOnSipMsg)(int call_id, int is_tx, const char *msg);

/* -----------------------------------------------------------------------
 * Configuration structures
 * ----------------------------------------------------------------------- */

/**
 * PJSUA configuration parameters.
 * All fields map to pjsua_config, pjsua_media_config, and pjsua_logging_config.
 * Zero/NULL values will use PJSIP defaults.
 */
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

/**
 * Initialize a PdConfig structure with default values.
 * @param cfg  Pointer to PdConfig structure to initialize.
 */
void pd_config_default(PdConfig *cfg);

/* -----------------------------------------------------------------------
 * Lifecycle
 * ----------------------------------------------------------------------- */

/**
 * Initialise pjsua, create transports, and start the worker thread.
 * Must be called once before any other pd_* function.
 *
 * @param cfg         Configuration parameters (use pd_config_default() to initialize).
 * @param on_reg      Callback for registration state changes.
 * @param on_incoming Callback for incoming calls.
 * @param on_call     Callback for call state changes.
 * @param on_media    Callback for call media state changes.
 * @param on_log      Callback for log messages.
 * @param on_sip_msg  Callback for raw SIP messages.
 * @return 0 on success, non-zero pj_status_t on error.
 */
int pd_init(const PdConfig   *cfg,
            PdOnRegState     on_reg,
            PdOnIncomingCall on_incoming,
            PdOnCallState    on_call,
            PdOnCallMedia    on_media,
            PdOnLog          on_log,
            PdOnSipMsg       on_sip_msg);

/** Destroy pjsua and release all resources. */
int pd_shutdown(void);

/* -----------------------------------------------------------------------
 * Account management
 * ----------------------------------------------------------------------- */

/**
 * Add a SIP account and start registration.
 *
 * @param sip_uri    AOR: "sip:username@server" or "sips:username@server"
 * @param registrar  Registrar URI: "sip:server[:port]"
 * @param username   Authentication username
 * @param password   Authentication password
 * @param use_tcp    0 = UDP transport, 1 = TCP transport
 * @return pjsua_acc_id (>= 0) on success, -1 on error.
 */
int pd_acc_add(const char *sip_uri, const char *registrar,
               const char *username, const char *password,
               const char *auth_username, const char *sip_proxy,
               int use_tcp);

/**
 * Remove a previously added account (triggers SIP unregistration).
 * @param acc_id  pjsua_acc_id returned by pd_acc_add.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_remove(int acc_id);

/* -----------------------------------------------------------------------
 * Call management
 * ----------------------------------------------------------------------- */

/**
 * Initiate an outgoing call.
 * @param acc_id   pjsua_acc_id to use for the call.
 * @param dst_uri  Destination SIP URI, e.g. "sip:bob@example.com".
 * @return pjsua_call_id (>= 0) on success, -1 on error.
 */
int pd_call_make(int acc_id, const char *dst_uri);

/**
 * Answer an incoming call with 200 OK.
 * @param call_id  pjsua_call_id.
 * @return 0 on success, non-zero on error.
 */
int pd_call_answer(int call_id);

/**
 * Hang up (or reject) a call.
 * @param call_id  pjsua_call_id.
 * @return 0 on success, non-zero on error.
 */
int pd_call_hangup(int call_id);

/**
 * Place a call on hold or resume it.
 * @param call_id  pjsua_call_id.
 * @param hold     1 to hold, 0 to resume.
 * @return 0 on success, non-zero on error.
 */
int pd_call_hold(int call_id, int hold);

/**
 * Mute or unmute the local microphone for a call.
 * Implemented by connecting/disconnecting the mic from the conference bridge.
 * @param call_id  pjsua_call_id.
 * @param mute     1 to mute, 0 to unmute.
 * @return 0 on success, non-zero on error.
 */
int pd_call_set_mute(int call_id, int mute);

/**
 * Send DTMF digits on a call.
 * @param call_id  pjsua_call_id.
 * @param digits   NUL-terminated string of DTMF digits (0-9, *, #, A-D).
 * @return 0 on success, non-zero on error.
 */
int pd_call_send_dtmf(int call_id, const char *digits);

/* -----------------------------------------------------------------------
 * Audio device management
 * ----------------------------------------------------------------------- */

/**
 * Return the number of available audio devices.
 */
unsigned pd_aud_dev_count(void);

/**
 * Get info for one audio device.
 * @param idx        Device index (0 .. pd_aud_dev_count()-1).
 * @param id_out     Receives the pjmedia device id.
 * @param name_buf   Caller-allocated buffer to receive device name.
 * @param name_len   Size of name_buf in bytes.
 * @param kind_out   Receives 0=input, 1=output, 2=both.
 * @return 0 on success, non-zero if idx is out of range.
 */
int pd_aud_dev_info(unsigned idx, int *id_out,
                    char *name_buf, int name_len, int *kind_out);

/**
 * Set the active capture and playback devices.
 * @param capture_id   pjmedia device id for microphone.
 * @param playback_id  pjmedia device id for speaker.
 * @return 0 on success, non-zero on error.
 */
int pd_aud_set_devs(int capture_id, int playback_id);

/**
 * Get the currently active capture and playback device ids.
 * @param capture_id_out   Receives capture device id.
 * @param playback_id_out  Receives playback device id.
 * @return 0 on success.
 */
int pd_aud_get_devs(int *capture_id_out, int *playback_id_out);

/* -----------------------------------------------------------------------
 * Stream statistics
 * ----------------------------------------------------------------------- */

/**
 * Get audio stream statistics for the first active audio stream of a call.
 * @param call_id           pjsua_call_id.
 * @param jitter_ms_out     Receives average receive jitter in milliseconds.
 * @param loss_pct_out      Receives receive packet-loss percentage (0–100).
 * @param codec_buf         Caller-allocated buffer for the codec name string.
 * @param codec_buf_len     Size of codec_buf in bytes.
 * @param bitrate_kbps_out  Receives estimated bitrate in kbps.
 * @return 0 on success, non-zero if call has no active audio stream.
 */
int pd_call_get_stream_stat(int call_id,
                             float *jitter_ms_out,
                             float *loss_pct_out,
                             char  *codec_buf,
                             int    codec_buf_len,
                             int   *bitrate_kbps_out);

#ifdef __cplusplus
}
#endif

#endif /* PACKETDIAL_PJSIP_SHIM_H */

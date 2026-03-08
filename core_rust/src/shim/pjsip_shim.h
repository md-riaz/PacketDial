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

/**
 * Call transfer status notification.
 * @param call_id     PJSIP call id
 * @param status_code SIP status code (200 = success, etc.)
 * @param reason      NUL-terminated status text
 * @param is_final    1 if this is the final notification, 0 otherwise
 */
typedef void (*PdOnCallTransferStatus)(int call_id, int status_code,
                                        const char *reason, int is_final);

/**
 * BLF/Presence status notification.
 * @param uri         SIP URI of the monitored extension
 * @param state       Presence state: 0=Unknown, 1=Available, 2=Busy, 3=Ringing
 * @param activity    NUL-terminated activity description
 */
typedef void (*PdOnBlfStatus)(const char *uri, int state, const char *activity);

/* -----------------------------------------------------------------------
 * Lifecycle
 * ----------------------------------------------------------------------- */

/**
 * Initialise pjsua, create transports, and start the worker thread.
 * Must be called once before any other pd_* function.
 *
 * @param stun_server  "host:port" string for STUN, or NULL to disable.
 * @param on_reg       Callback for registration state changes.
 * @param on_incoming  Callback for incoming calls.
 * @param on_call      Callback for call state changes.
 * @param on_media     Callback for call media state changes.
 * @param on_log       Callback for log messages.
 * @param on_sip_msg   Callback for raw SIP messages.
 * @param on_transfer_status Callback for call transfer status notifications.
 * @return 0 on success, non-zero pj_status_t on error.
 */
int pd_init(const char *user_agent,
            const char *stun_server,
            PdOnRegState     on_reg,
            PdOnIncomingCall on_incoming,
            PdOnCallState    on_call,
            PdOnCallMedia    on_media,
            PdOnLog          on_log,
            PdOnSipMsg       on_sip_msg,
            PdOnCallTransferStatus on_transfer_status,
            PdOnBlfStatus    on_blf_status);

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
               int use_tcp, const char *stun_server);

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

/**
 * Initiate blind call transfer to the specified destination.
 * Sends SIP REFER request to transfer the call to dest_uri.
 * @param call_id   pjsua_call_id of the call to transfer.
 * @param dest_uri  Destination SIP URI to transfer the call to.
 * @return 0 on success, non-zero on error.
 */
int pd_call_transfer(int call_id, const char *dest_uri);

/**
 * Initiate attended (consultative) call transfer.
 * First puts the current call on hold, then initiates a new call to the
 * transfer target. After the target answers, call pd_call_complete_xfer()
 * to complete the transfer.
 * @param call_id   pjsua_call_id of the call to transfer (call A).
 * @param dest_uri  Destination SIP URI to consult with.
 * @return New pjsua_call_id for the consultation call (call B), or -1 on error.
 */
int pd_call_start_attended_xfer(int call_id, const char *dest_uri);

/**
 * Complete an attended transfer by transferring call A to call B's target.
 * This connects the original caller directly to the consultation target.
 * @param call_a    pjsua_call_id of the original call (on hold).
 * @param call_b    pjsua_call_id of the consultation call.
 * @return 0 on success, non-zero on error.
 */
int pd_call_complete_xfer(int call_a, int call_b);

/**
 * Merge two calls into a 3-way conference.
 * Both calls must be active (not on hold).
 * @param call_a    pjsua_call_id of the first call.
 * @param call_b    pjsua_call_id of the second call.
 * @return 0 on success, non-zero on error.
 */
int pd_call_merge_conference(int call_a, int call_b);

/**
 * Set call forwarding for an account.
 * @param acc_id        pjsua_acc_id.
 * @param fwd_uri       Forward-to SIP URI (NULL to disable).
 * @param fwd_flags     Forward flags: 1=Unconditional, 2=OnBusy, 4=OnNoAnswer.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_set_forward(int acc_id, const char *fwd_uri, int fwd_flags);

/**
 * Get current call forwarding settings for an account.
 * @param acc_id        pjsua_acc_id.
 * @param fwd_uri_buf   Buffer to receive forward-to URI.
 * @param fwd_uri_len   Size of fwd_uri_buf.
 * @param fwd_flags_out Receives forward flags.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_get_forward(int acc_id, char *fwd_uri_buf, int fwd_uri_len,
                        int *fwd_flags_out);

/**
 * Enable/Disable Do Not Disturb (DND) mode.
 * @param acc_id    pjsua_acc_id.
 * @param enabled   1 to enable DND, 0 to disable.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_set_dnd(int acc_id, int enabled);

/**
 * Subscribe to BLF/Presence for a list of URIs.
 * @param acc_id    pjsua_acc_id to use for subscription.
 * @param uris      Array of SIP URIs to monitor.
 * @param count     Number of URIs in the array.
 * @return 0 on success, non-zero on error.
 */
int pd_blf_subscribe(int acc_id, const char **uris, int count);

/**
 * Unsubscribe from all BLF/Presence subscriptions.
 * @param acc_id    pjsua_acc_id.
 * @return 0 on success, non-zero on error.
 */
int pd_blf_unsubscribe(int acc_id);

/**
 * Set caller lookup URL for an account.
 * @param acc_id        pjsua_acc_id.
 * @param lookup_url    URL template for caller lookup (e.g., "https://example.com/search?q={number}").
 * @return 0 on success, non-zero on error.
 */
int pd_acc_set_lookup_url(int acc_id, const char *lookup_url);

/**
 * Get caller lookup URL for an account.
 * @param acc_id        pjsua_acc_id.
 * @param url_buf       Buffer to receive lookup URL.
 * @param url_len       Size of url_buf.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_get_lookup_url(int acc_id, char *url_buf, int url_len);

/**
 * Set codec priority for an account.
 * @param acc_id            pjsua_acc_id.
 * @param codec_priorities  JSON array of {codec: "PCMU", priority: 1}, ...
 * @return 0 on success, non-zero on error.
 */
int pd_acc_set_codec_priority(int acc_id, const char *codec_priorities);

/**
 * Get codec priority settings for an account.
 * @param acc_id            pjsua_acc_id.
 * @param json_buf          Buffer to receive JSON codec priorities.
 * @param json_len          Size of json_buf.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_get_codec_priority(int acc_id, char *json_buf, int json_len);

/**
 * Enable/disable specific codec for an account.
 * @param acc_id            pjsua_acc_id.
 * @param codec_id          Codec ID (e.g., "PCMU", "PCMA", "G729", "OPUS").
 * @param enabled           1 to enable, 0 to disable.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_set_codec(int acc_id, const char *codec_id, int enabled);

/**
 * Set auto-answer settings for an account.
 * @param acc_id            pjsua_acc_id.
 * @param enabled           1 to enable auto-answer, 0 to disable.
 * @param delay_ms          Delay in milliseconds before auto-answering.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_set_auto_answer(int acc_id, int enabled, int delay_ms);

/**
 * Get auto-answer settings for an account.
 * @param acc_id            pjsua_acc_id.
 * @param enabled_out       Receives enabled setting.
 * @param delay_ms_out      Receives delay in milliseconds.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_get_auto_answer(int acc_id, int *enabled_out, int *delay_ms_out);

/**
 * Set DTMF transmission method for an account.
 * @param acc_id            pjsua_acc_id.
 * @param dtmf_method       Method: 0=In-band, 1=RFC2833, 2=SIP INFO.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_set_dtmf_method(int acc_id, int dtmf_method);

/**
 * Get DTMF transmission method for an account.
 * @param acc_id            pjsua_acc_id.
 * @param method_out        Receives DTMF method.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_get_dtmf_method(int acc_id, int *method_out);

/**
 * Export account configuration to JSON string.
 * @param acc_id            pjsua_acc_id.
 * @param json_buf          Buffer to receive JSON configuration.
 * @param json_len          Size of json_buf.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_export_config(int acc_id, char *json_buf, int json_len);

/**
 * Import account configuration from JSON string.
 * @param json_str          JSON configuration string.
 * @param new_acc_id_out    Receives new account ID if successful.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_import_config(const char *json_str, int *new_acc_id_out);

/**
 * Delete an account profile by UUID.
 * @param uuid              Account UUID string.
 * @return 0 on success, non-zero on error.
 */
int pd_acc_delete_profile(const char *uuid);

/* -----------------------------------------------------------------------
 * Global (App-Wide) Settings
 * ----------------------------------------------------------------------- */

/**
 * Set global codec priority (applies to all accounts).
 * @param codec_priorities  JSON array of {codec: "PCMU", priority: 1}, ...
 * @return 0 on success, non-zero on error.
 */
int pd_set_global_codec_priority(const char *codec_priorities);

/**
 * Get global codec priority settings.
 * @param json_buf          Buffer to receive JSON codec priorities.
 * @param json_len          Size of json_buf.
 * @return 0 on success, non-zero on error.
 */
int pd_get_global_codec_priority(char *json_buf, int json_len);

/**
 * Set global DTMF transmission method (applies to all accounts).
 * @param dtmf_method       Method: 0=In-band, 1=RFC2833, 2=SIP INFO.
 * @return 0 on success, non-zero on error.
 */
int pd_set_global_dtmf_method(int dtmf_method);

/**
 * Get global DTMF transmission method.
 * @param method_out        Receives DTMF method.
 * @return 0 on success, non-zero on error.
 */
int pd_get_global_dtmf_method(int *method_out);

/**
 * Set global auto-answer settings (applies to all accounts).
 * @param enabled           1 to enable auto-answer, 0 to disable.
 * @param delay_ms          Delay in milliseconds before auto-answering.
 * @return 0 on success, non-zero on error.
 */
int pd_set_global_auto_answer(int enabled, int delay_ms);

/**
 * Get global auto-answer settings.
 * @param enabled_out       Receives enabled setting.
 * @param delay_ms_out      Receives delay in milliseconds.
 * @return 0 on success, non-zero on error.
 */
int pd_get_global_auto_answer(int *enabled_out, int *delay_ms_out);

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

/**
 * Play DTMF tones locally through the system speaker.
 * @param digits   NUL-terminated string of DTMF digits (0-9, *, #, A-D).
 * @return 0 on success, non-zero on error.
 */
int pd_aud_play_dtmf(const char *digits);

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

/* -----------------------------------------------------------------------
 * Call Recording
 * ----------------------------------------------------------------------- */

/**
 * Start recording a call to a WAV file.
 * @param call_id    pjsua_call_id of the call to record.
 * @param file_path  Full path to the output WAV file.
 * @return 0 on success, non-zero on error.
 */
int pd_call_start_recording(int call_id, const char *file_path);

/**
 * Stop recording the current call.
 * @param call_id  pjsua_call_id of the call being recorded.
 * @return 0 on success, non-zero on error.
 */
int pd_call_stop_recording(int call_id);

/**
 * Check if a call is currently being recorded.
 * @param call_id  pjsua_call_id of the call.
 * @return 1 if recording, 0 if not recording or error.
 */
int pd_call_is_recording(int call_id);

#ifdef __cplusplus
}
#endif

#endif /* PACKETDIAL_PJSIP_SHIM_H */

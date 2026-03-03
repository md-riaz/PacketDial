/*
 * pjsip_shim.c — PacketDial thin C wrapper around pjsua.
 *
 * Compiled only when PJSIP headers and static libraries are available
 * (see core_rust/build.rs which gates compilation on the shim file + include
 * directory both existing).
 *
 * All public functions use the pd_* prefix.  Internal PJSIP callbacks are
 * static and named with the on_* prefix.
 */

#include "pjsip_shim.h"

#include <pjsua-lib/pjsua.h>
#include <pjmedia/audiodev.h>

#include <string.h>
#include <stdio.h>

/* -----------------------------------------------------------------------
 * Module-level globals
 * ----------------------------------------------------------------------- */

/* Rust callback function pointers — set once in pd_init, read-only after */
static PdOnRegState     g_on_reg      = NULL;
static PdOnIncomingCall g_on_incoming = NULL;
static PdOnCallState    g_on_call     = NULL;
static PdOnCallMedia    g_on_media    = NULL;
static PdOnLog          g_on_log      = NULL;
static PdOnSipMsg       g_on_sip_msg  = NULL;

/* Transport ids created at init time */
static pjsua_transport_id g_udp_tp = PJSUA_INVALID_ID;
static pjsua_transport_id g_tcp_tp = PJSUA_INVALID_ID;

/* -----------------------------------------------------------------------
 * Internal helpers
 * ----------------------------------------------------------------------- */

/* Safe snprintf wrapper that always NUL-terminates */
static void safe_copy(char *dst, int dst_len, const char *src)
{
    if (!dst || dst_len <= 0) return;
    if (!src) { dst[0] = '\0'; return; }
#if defined(_MSC_VER)
    _snprintf_s(dst, (size_t)dst_len, _TRUNCATE, "%s", src);
#else
    snprintf(dst, (size_t)dst_len, "%s", src);
#endif
    dst[dst_len - 1] = '\0';
}

/* pj_str_t from a C string literal / pointer.
 * PJSIP expects char* not const char*, so we cast; the value is never
 * written back through the pointer by pjsua APIs we use here. */
static pj_str_t S(const char *s)
{
    pj_str_t r;
    r.ptr = (char *)s;
    r.slen = (pj_ssize_t)(s ? strlen(s) : 0);
    return r;
}

/* -----------------------------------------------------------------------
 * PJSUA callback implementations
 * ----------------------------------------------------------------------- */

static void on_reg_state(pjsua_acc_id acc_id)
{
    if (!g_on_reg) return;

    pjsua_acc_info info;
    pj_bzero(&info, sizeof(info));
    if (pjsua_acc_get_info(acc_id, &info) != PJ_SUCCESS) return;

    /* Copy status_text to a NUL-terminated buffer */
    char reason[128];
    pj_ssize_t len = info.status_text.slen;
    if (len >= (pj_ssize_t)sizeof(reason)) len = (pj_ssize_t)sizeof(reason) - 1;
    memcpy(reason, info.status_text.ptr, (size_t)len);
    reason[len] = '\0';

    g_on_reg((int)acc_id, info.expires, (int)info.status, reason);
}

static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id,
                              pjsip_rx_data *rdata)
{
    (void)rdata;
    if (!g_on_incoming) return;

    pjsua_call_info ci;
    pj_bzero(&ci, sizeof(ci));
    if (pjsua_call_get_info(call_id, &ci) != PJ_SUCCESS) return;

    /* Extract "From" URI as a NUL-terminated string */
    char from_uri[256];
    pj_ssize_t len = ci.remote_info.slen;
    if (len >= (pj_ssize_t)sizeof(from_uri)) len = (pj_ssize_t)sizeof(from_uri) - 1;
    memcpy(from_uri, ci.remote_info.ptr, (size_t)len);
    from_uri[len] = '\0';

    g_on_incoming((int)acc_id, (int)call_id, from_uri);
}

static void on_call_state(pjsua_call_id call_id, pjsip_event *e)
{
    (void)e;
    if (!g_on_call) return;

    pjsua_call_info ci;
    pj_bzero(&ci, sizeof(ci));
    if (pjsua_call_get_info(call_id, &ci) != PJ_SUCCESS) return;

    g_on_call((int)call_id, (int)ci.state, (int)ci.last_status);
}

static void on_call_media_state(pjsua_call_id call_id)
{
    pjsua_call_info ci;
    pj_bzero(&ci, sizeof(ci));
    if (pjsua_call_get_info(call_id, &ci) != PJ_SUCCESS) return;

    int any_active = 0;
    unsigned i;
    for (i = 0; i < ci.media_cnt; i++) {
        if (ci.media[i].type == PJMEDIA_TYPE_AUDIO) {
            pjsua_call_media_status st = ci.media[i].status;
            if (st == PJSUA_CALL_MEDIA_ACTIVE) {
                /* Connect conference bridge ports:
                 *   call → speaker (port 0)
                 *   mic  (port 0) → call */
                pjsua_conf_port_id slot = ci.media[i].stream.aud.conf_slot;
                pjsua_conf_connect(slot, 0);
                pjsua_conf_connect(0, slot);
                any_active = 1;
            }
        }
    }

    if (g_on_media) {
        g_on_media((int)call_id, any_active);
    }
}

static void on_call_tsx_state(pjsua_call_id call_id, pjsip_transaction *tsx,
                               pjsip_event *e)
{
    if (!g_on_sip_msg) return;

    /* Capture outgoing SIP messages */
    if (e->body.tsx_state.type == PJSIP_EVENT_TX_MSG && tsx && tsx->last_tx) {
        char buf[4096];
        pj_ssize_t len = pjsip_msg_print(tsx->last_tx->msg, buf,
                                          sizeof(buf) - 1);
        if (len > 0) {
            buf[len] = '\0';
            g_on_sip_msg((int)call_id, 1, buf);
        }
    }
    /* Capture incoming SIP messages */
    else if (e->body.tsx_state.type == PJSIP_EVENT_RX_MSG &&
             e->body.tsx_state.src.rdata) {
        pjsip_rx_data *rdata = e->body.tsx_state.src.rdata;
        char buf[4096];
        pj_ssize_t len = pjsip_msg_print(rdata->msg_info.msg, buf,
                                          sizeof(buf) - 1);
        if (len > 0) {
            buf[len] = '\0';
            g_on_sip_msg((int)call_id, 0, buf);
        }
    }
}

/* PJSIP log writer — forwards to the Rust log callback */
static void pj_log_writer(int level, const char *data, int len)
{
    if (!g_on_log || len <= 0) return;

    /* Strip trailing newline that pjsip appends */
    char buf[2048];
    int copy = len;
    if (copy >= (int)sizeof(buf)) copy = (int)sizeof(buf) - 1;
    memcpy(buf, data, (size_t)copy);
    while (copy > 0 && (buf[copy - 1] == '\n' || buf[copy - 1] == '\r'))
        copy--;
    buf[copy] = '\0';

    g_on_log(level, buf);
}

/* -----------------------------------------------------------------------
 * pd_init
 * ----------------------------------------------------------------------- */

int pd_init(const char *user_agent,
            const char *stun_server,
            PdOnRegState     on_reg,
            PdOnIncomingCall on_incoming,
            PdOnCallState    on_call,
            PdOnCallMedia    on_media,
            PdOnLog          on_log,
            PdOnSipMsg       on_sip_msg)
{
    pj_status_t status;

    /* Save callbacks */
    g_on_reg      = on_reg;
    g_on_incoming = on_incoming;
    g_on_call     = on_call;
    g_on_media    = on_media;
    g_on_log      = on_log;
    g_on_sip_msg  = on_sip_msg;

    /* pjsua_create */
    status = pjsua_create();
    if (status != PJ_SUCCESS) return (int)status;

    /* Logging config */
    pjsua_logging_config log_cfg;
    pjsua_logging_config_default(&log_cfg);
    log_cfg.level      = 4;          /* capture up to debug from pjsip */
    log_cfg.console_level = 0;       /* suppress console output */
    log_cfg.cb         = pj_log_writer;
    log_cfg.msg_logging = PJ_TRUE;   /* enable SIP message logging */

    /* UA config */
    pjsua_config ua_cfg;
    pjsua_config_default(&ua_cfg);
    ua_cfg.cb.on_reg_state      = on_reg_state;
    ua_cfg.cb.on_incoming_call  = on_incoming_call;
    ua_cfg.cb.on_call_state     = on_call_state;
    ua_cfg.cb.on_call_media_state = on_call_media_state;
    ua_cfg.cb.on_call_tsx_state = on_call_tsx_state;

    if (user_agent && user_agent[0] != '\0') {
        ua_cfg.user_agent = S(user_agent);
    }

    ua_cfg.max_calls            = 8;

    if (stun_server && stun_server[0] != '\0') {
        ua_cfg.stun_srv_cnt = 1;
        ua_cfg.stun_srv[0]  = S(stun_server);
    }

    /* Media config */
    pjsua_media_config med_cfg;
    pjsua_media_config_default(&med_cfg);
    /* 16 kHz wideband audio: good balance of quality and bandwidth for VOIP.
     * Set to 8000 for narrowband (G.711) compatibility if needed. */
    med_cfg.clock_rate     = 16000;
    med_cfg.snd_clock_rate = 0;       /* follow clock_rate */
    /* 200 ms echo-canceller tail covers typical room acoustics; increase to
     * 500 ms for far-end echo on speaker-phone setups. */
    med_cfg.ec_tail_len    = 200;
    med_cfg.no_vad         = PJ_FALSE;

    status = pjsua_init(&ua_cfg, &log_cfg, &med_cfg);
    if (status != PJ_SUCCESS) {
        pjsua_destroy();
        return (int)status;
    }

    /* Create UDP transport (port 0 = OS-assigned) */
    pjsua_transport_config tp_cfg;
    pjsua_transport_config_default(&tp_cfg);
    tp_cfg.port = 0;

    status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &tp_cfg, &g_udp_tp);
    if (status != PJ_SUCCESS) {
        pjsua_destroy();
        return (int)status;
    }

    /* Create TCP transport (optional — ignore failure) */
    status = pjsua_transport_create(PJSIP_TRANSPORT_TCP, &tp_cfg, &g_tcp_tp);
    if (status != PJ_SUCCESS) {
        g_tcp_tp = PJSUA_INVALID_ID; /* TCP unavailable — UDP only */
    }

    /* Start */
    status = pjsua_start();
    if (status != PJ_SUCCESS) {
        pjsua_destroy();
        return (int)status;
    }

    return 0;
}

/* -----------------------------------------------------------------------
 * pd_shutdown
 * ----------------------------------------------------------------------- */

int pd_shutdown(void)
{
    pj_status_t status = pjsua_destroy();
    g_udp_tp = PJSUA_INVALID_ID;
    g_tcp_tp = PJSUA_INVALID_ID;
    return (int)status;
}

/* -----------------------------------------------------------------------
 * Account management
 * ----------------------------------------------------------------------- */

int pd_acc_add(const char *sip_uri, const char *registrar,
               const char *username, const char *password,
               const char *auth_username, const char *sip_proxy,
               int use_tcp)
{
    pjsua_acc_config cfg;
    pjsua_acc_config_default(&cfg);

    cfg.id      = S(sip_uri);
    cfg.reg_uri = S(registrar);

    /* Credential — match any realm */
    cfg.cred_count = 1;
    cfg.cred_info[0].realm     = S("*");
    cfg.cred_info[0].scheme    = S("digest");
    cfg.cred_info[0].username  = S(auth_username && auth_username[0] != '\0' ? auth_username : username);
    cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    cfg.cred_info[0].data      = S(password);

    /* Proxy configuration */
    if (sip_proxy && sip_proxy[0] != '\0') {
        cfg.proxy_cnt = 1;
        cfg.proxy[0] = S(sip_proxy);
    }

    /* Transport selection */
    if (use_tcp && g_tcp_tp != PJSUA_INVALID_ID) {
        cfg.transport_id = g_tcp_tp;
    } else {
        cfg.transport_id = g_udp_tp;
    }

    /* Registration options */
    cfg.register_on_acc_add = PJ_TRUE;
    cfg.reg_retry_interval  = 60;   /* retry every 60 s on failure */
    cfg.reg_first_retry_interval = 5;

    pjsua_acc_id acc_id;
    pj_status_t status = pjsua_acc_add(&cfg, PJ_TRUE, &acc_id);
    if (status != PJ_SUCCESS) return -1;
    return (int)acc_id;
}

int pd_acc_remove(int acc_id)
{
    return (int)pjsua_acc_del((pjsua_acc_id)acc_id);
}

/* -----------------------------------------------------------------------
 * Call management
 * ----------------------------------------------------------------------- */

int pd_call_make(int acc_id, const char *dst_uri)
{
    pj_str_t dst = S(dst_uri);
    pjsua_call_id call_id;
    pj_status_t status = pjsua_call_make_call((pjsua_acc_id)acc_id, &dst,
                                               NULL, NULL, NULL, &call_id);
    if (status != PJ_SUCCESS) return -1;
    return (int)call_id;
}

int pd_call_answer(int call_id)
{
    return (int)pjsua_call_answer((pjsua_call_id)call_id, 200, NULL, NULL);
}

int pd_call_hangup(int call_id)
{
    return (int)pjsua_call_hangup((pjsua_call_id)call_id, 0, NULL, NULL);
}

int pd_call_hold(int call_id, int hold)
{
    if (hold) {
        return (int)pjsua_call_set_hold((pjsua_call_id)call_id, NULL);
    } else {
        return (int)pjsua_call_reinvite((pjsua_call_id)call_id, PJSUA_CALL_UNHOLD, NULL);
    }
}

int pd_call_set_mute(int call_id, int mute)
{
    pjsua_call_info ci;
    pj_bzero(&ci, sizeof(ci));
    if (pjsua_call_get_info((pjsua_call_id)call_id, &ci) != PJ_SUCCESS)
        return -1;

    unsigned i;
    for (i = 0; i < ci.media_cnt; i++) {
        if (ci.media[i].type == PJMEDIA_TYPE_AUDIO &&
            ci.media[i].status == PJSUA_CALL_MEDIA_ACTIVE) {
            pjsua_conf_port_id slot = ci.media[i].stream.aud.conf_slot;
            if (mute) {
                /* Disconnect mic (port 0) from the call's audio slot */
                pjsua_conf_disconnect(0, slot);
            } else {
                /* Reconnect mic to the call's audio slot */
                pjsua_conf_connect(0, slot);
            }
        }
    }
    return 0;
}

int pd_call_send_dtmf(int call_id, const char *digits)
{
    if (!digits || digits[0] == '\0') return -1;
    pj_str_t d = S(digits);
    return (int)pjsua_call_dial_dtmf((pjsua_call_id)call_id, &d);
}

/* -----------------------------------------------------------------------
 * Audio device management
 * ----------------------------------------------------------------------- */

unsigned pd_aud_dev_count(void)
{
    pjmedia_aud_dev_info infos[64];
    unsigned count = 64;
    pj_status_t st = pjsua_enum_aud_devs(infos, &count);
    if (st != PJ_SUCCESS) return 0;
    return count;
}

int pd_aud_dev_info(unsigned idx, int *id_out,
                    char *name_buf, int name_len, int *kind_out)
{
    pjmedia_aud_dev_info infos[64];
    unsigned count = 64;
    if (pjsua_enum_aud_devs(infos, &count) != PJ_SUCCESS) return -1;
    if (idx >= count) return -1;

    if (id_out)   *id_out = (int)idx;
    if (name_buf) safe_copy(name_buf, name_len, infos[idx].name);

    if (kind_out) {
        int has_input  = (infos[idx].input_count > 0);
        int has_output = (infos[idx].output_count > 0);
        if (has_input && has_output)
            *kind_out = 2; /* both */
        else if (has_input)
            *kind_out = 0; /* input */
        else
            *kind_out = 1; /* output */
    }
    return 0;
}

int pd_aud_set_devs(int capture_id, int playback_id)
{
    return (int)pjsua_set_snd_dev(capture_id, playback_id);
}

int pd_aud_get_devs(int *capture_id_out, int *playback_id_out)
{
    int cap = -1, play = -1;
    pj_status_t st = pjsua_get_snd_dev(&cap, &play);
    if (capture_id_out)  *capture_id_out  = cap;
    if (playback_id_out) *playback_id_out = play;
    return (int)st;
}

/* -----------------------------------------------------------------------
 * Stream statistics
 * ----------------------------------------------------------------------- */

int pd_call_get_stream_stat(int call_id,
                             float *jitter_ms_out,
                             float *loss_pct_out,
                             char  *codec_buf,
                             int    codec_buf_len,
                             int   *bitrate_kbps_out)
{
    pjsua_call_info ci;
    pj_bzero(&ci, sizeof(ci));
    if (pjsua_call_get_info((pjsua_call_id)call_id, &ci) != PJ_SUCCESS)
        return -1;

    /* Find the first active audio stream */
    unsigned i;
    int stream_idx = -1;
    for (i = 0; i < ci.media_cnt; i++) {
        if (ci.media[i].type == PJMEDIA_TYPE_AUDIO &&
            ci.media[i].status == PJSUA_CALL_MEDIA_ACTIVE) {
            stream_idx = (int)i;
            break;
        }
    }
    if (stream_idx < 0) return -1;

    /* Retrieve stream statistics */
    pjsua_stream_stat stat;
    pj_bzero(&stat, sizeof(stat));
    if (pjsua_call_get_stream_stat((pjsua_call_id)call_id,
                                    (unsigned)stream_idx, &stat) != PJ_SUCCESS)
        return -1;

    /* Jitter: mean value in usec → convert to ms */
    if (jitter_ms_out)
        *jitter_ms_out = (float)stat.rtcp.rx.jitter.mean / 1000.0f;

    /* Packet loss percentage */
    if (loss_pct_out) {
        unsigned total = stat.rtcp.rx.pkt + stat.rtcp.rx.loss;
        *loss_pct_out = (total > 0)
            ? (float)stat.rtcp.rx.loss * 100.0f / (float)total
            : 0.0f;
    }

    /* Codec name */
    if (codec_buf && codec_buf_len > 0) {
        pjsua_stream_info si;
        pj_bzero(&si, sizeof(si));
        if (pjsua_call_get_stream_info((pjsua_call_id)call_id,
                                        (unsigned)stream_idx, &si) == PJ_SUCCESS
            && si.type == PJMEDIA_TYPE_AUDIO) {
            pj_ssize_t clen = si.info.aud.fmt.encoding_name.slen;
            if (clen >= (pj_ssize_t)codec_buf_len)
                clen = (pj_ssize_t)codec_buf_len - 1;
            memcpy(codec_buf, si.info.aud.fmt.encoding_name.ptr, (size_t)clen);
            codec_buf[clen] = '\0';
        } else {
            safe_copy(codec_buf, codec_buf_len, "unknown");
        }
    }

    /* Approximate bitrate: use RTCP-reported bytes and the session duration.
     * pjmedia tracks bytes since the start of the session; divide by elapsed
     * seconds to get bytes/s, then convert to kbps. Fall back to 64 kbps
     * (G.711 typical) if insufficient data is available. */
    if (bitrate_kbps_out) {
        unsigned tx_bytes = stat.rtcp.tx.bytes;
        double elapsed = 0.0;
        /* pjmedia records session start in stat.start */
        {
            pj_time_val now;
            pj_gettimeofday(&now);
            pj_time_val start = stat.rtcp.start;
            pj_time_val diff;
            diff.sec  = now.sec  - start.sec;
            diff.msec = now.msec - start.msec;
            pj_time_val_normalize(&diff);
            elapsed = (double)diff.sec + (double)diff.msec / 1000.0;
        }
        if (elapsed > 1.0 && tx_bytes > 0) {
            *bitrate_kbps_out = (int)((double)tx_bytes * 8.0 / elapsed / 1000.0);
        } else {
            *bitrate_kbps_out = 64; /* G.711 typical default */
        }
    }

    return 0;
}

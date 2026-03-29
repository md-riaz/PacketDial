/*
 * PacketDial Android pjproject configuration.
 *
 * This mirrors the shared desktop/mobile constraints used by PacketDial's
 * audio-only telephony engine while enabling Android-specific audio backends.
 */

#ifndef PACKETDIAL_ANDROID_CONFIG_SITE_H
#define PACKETDIAL_ANDROID_CONFIG_SITE_H

#define PJ_IOQUEUE_MAX_HANDLES              64
#define PJ_HAS_IPV6                         1

#define PJSUA_MAX_ACC                       4
#define PJSUA_MAX_CALLS                     8
#define PJSIP_MAX_DIALOG_COUNT              32

/* Android audio backends */
#define PJMEDIA_AUDIO_DEV_HAS_OPENSL        1
#define PJMEDIA_AUDIO_DEV_HAS_ANDROID_JNI   1
#define PJMEDIA_AUDIO_DEV_HAS_NULL_AUDIO    1

/* PacketDial Android bootstrap is audio-only and keeps media processing
 * conservative until the shared native core is fully stabilized.
 */
#define PJMEDIA_HAS_SPEEX_AEC               0
#define PJMEDIA_HAS_WEBRTC_AEC              0

/* Security
 * Android port bootstrap uses UDP/TCP first; TLS can be re-enabled once
 * an Android OpenSSL/BoringSSL toolchain is staged for the shared core.
 */
#define PJSIP_HAS_TLS_TRANSPORT             0
#ifndef PJ_HAS_SSL_SOCK
#define PJ_HAS_SSL_SOCK                     0
#endif

/* PacketDial is audio-only */
#define PJMEDIA_HAS_VIDEO                   0
#define PJSUA_HAS_VIDEO                     0

/* Logging */
#define PJ_LOG_MAX_LEVEL                    5

#endif /* PACKETDIAL_ANDROID_CONFIG_SITE_H */

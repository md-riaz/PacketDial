/*
 * PacketDial — pjproject compile-time configuration.
 *
 * This file is committed to the repository and is copied into
 * engine_pjsip/pjproject/pjlib/include/pj/config_site.h by
 * scripts/fetch_pjsip.ps1 during the build setup.
 *
 * Reference: https://docs.pjsip.org/en/latest/get-started/configuration.html
 */

#ifndef PACKETDIAL_CONFIG_SITE_H
#define PACKETDIAL_CONFIG_SITE_H

/* -----------------------------------------------------------------------
 * Platform: Windows x64, MSVC toolchain
 * ----------------------------------------------------------------------- */

/* IOQueue settings - must be defined before pj/ioqueue.h is included */
#define PJ_IOQUEUE_MAX_HANDLES          64

/* Enable IPv6 support */
#define PJ_HAS_IPV6                     1

/* -----------------------------------------------------------------------
 * Account and call limits (PacketDial is a single-user client)
 * ----------------------------------------------------------------------- */
#define PJSUA_MAX_ACC                   4
#define PJSUA_MAX_CALLS                 8
#define PJSIP_MAX_DIALOG_COUNT          32

/* -----------------------------------------------------------------------
 * Audio device backends
 * ----------------------------------------------------------------------- */
/* Use Windows Audio Session API (WASAPI) — low-latency, recommended on Win10+ */
#define PJMEDIA_AUDIO_DEV_HAS_WASAPI    1
/* Also keep Windows Multimedia Extensions for broader device compatibility */
#define PJMEDIA_AUDIO_DEV_HAS_WMME      1
/* Enable Null Audio device for headless environments (CI/VMs) */
#define PJMEDIA_AUDIO_DEV_HAS_NULL_AUDIO 1
/* Disable WMME when WASAPI is preferred (WASAPI takes precedence) */
#define PJMEDIA_AUDIO_DEV_WMME_STATIC_DEFAULT 0

/* -----------------------------------------------------------------------
 * Security
 * ----------------------------------------------------------------------- */
/* Enable TLS transport for SIP over TLS (SIPS) */
#define PJSIP_HAS_TLS_TRANSPORT         1

/* Enable SSL socket support using OpenSSL */
#ifndef PJ_HAS_SSL_SOCK
#define PJ_HAS_SSL_SOCK                 1
#endif

/* -----------------------------------------------------------------------
 * Logging (pjlib level)
 * The Rust wrapper adds its own log layer on top; keep pjlib logging minimal.
 * Level 3 = Warnings and errors only in release builds.
 * ----------------------------------------------------------------------- */
#define PJ_LOG_MAX_LEVEL                5

/* -----------------------------------------------------------------------
 * Reduce binary size for a desktop client
 * ----------------------------------------------------------------------- */
/* Disable video (audio-only SIP client) */
#define PJMEDIA_HAS_VIDEO               0
#define PJSUA_HAS_VIDEO                 0

#endif /* PACKETDIAL_CONFIG_SITE_H */

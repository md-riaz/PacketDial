#ifndef FLUTTER_PLUGIN_VOIP_BRIDGE_H_
#define FLUTTER_PLUGIN_VOIP_BRIDGE_H_

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

typedef void (*voip_event_callback_t)(int32_t event_id, const char *payload);

FFI_PLUGIN_EXPORT int32_t voip_core_init(const char *json_config);
FFI_PLUGIN_EXPORT int32_t voip_core_shutdown(void);
FFI_PLUGIN_EXPORT int32_t voip_core_set_event_callback(voip_event_callback_t cb);

FFI_PLUGIN_EXPORT int32_t voip_account_upsert(const char *json_account);
FFI_PLUGIN_EXPORT int32_t voip_account_remove(const char *account_id);
FFI_PLUGIN_EXPORT int32_t voip_account_register(const char *account_id);
FFI_PLUGIN_EXPORT int32_t voip_account_unregister(const char *account_id);

FFI_PLUGIN_EXPORT int32_t voip_call_start(
    const char *account_id,
    const char *destination,
    char *out_call_id,
    int32_t out_len);
FFI_PLUGIN_EXPORT int32_t voip_call_answer(const char *call_id);
FFI_PLUGIN_EXPORT int32_t voip_call_reject(const char *call_id);
FFI_PLUGIN_EXPORT int32_t voip_call_hangup(const char *call_id);

FFI_PLUGIN_EXPORT int32_t voip_call_set_mute(const char *call_id, int32_t muted);
FFI_PLUGIN_EXPORT int32_t voip_call_set_hold(const char *call_id, int32_t hold);
FFI_PLUGIN_EXPORT int32_t voip_call_send_dtmf(const char *call_id, const char *digits);
FFI_PLUGIN_EXPORT int32_t voip_debug_simulate_incoming(
    const char *account_id,
    const char *remote_uri,
    const char *display_name);

FFI_PLUGIN_EXPORT int32_t voip_call_transfer_blind(const char *call_id, const char *dest);
FFI_PLUGIN_EXPORT int32_t voip_call_transfer_attended_start(
    const char *call_id,
    const char *dest,
    char *out_consult_id,
    int32_t out_len);
FFI_PLUGIN_EXPORT int32_t voip_call_transfer_attended_complete(
    const char *call_a,
    const char *call_b);

FFI_PLUGIN_EXPORT int32_t voip_audio_set_route(int32_t route);
FFI_PLUGIN_EXPORT int32_t voip_diag_export(
    const char *directory_path,
    char *out_file_path,
    int32_t out_len);

#endif

#ifndef PACKETDIAL_VOIP_CORE_H
#define PACKETDIAL_VOIP_CORE_H

#include <stdint.h>

#if defined(_WIN32)
#define VOIP_CORE_EXPORT __declspec(dllexport)
#else
#define VOIP_CORE_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*voip_core_event_callback_t)(int event_id, const char *json_payload);

enum PacketDialEventId {
  PD_EVENT_ENGINE_READY = 1,
  PD_EVENT_REGISTRATION_STATE_CHANGED = 2,
  PD_EVENT_CALL_STATE_CHANGED = 3,
  PD_EVENT_MEDIA_STATS_UPDATED = 4,
  PD_EVENT_AUDIO_DEVICE_LIST = 5,
  PD_EVENT_AUDIO_DEVICES_SET = 6,
  PD_EVENT_CALL_HISTORY_RESULT = 7,
  PD_EVENT_SIP_MESSAGE_CAPTURED = 8,
  PD_EVENT_DIAG_BUNDLE_READY = 9,
  PD_EVENT_ACCOUNT_SECURITY_UPDATED = 10,
  PD_EVENT_CRED_STORED = 11,
  PD_EVENT_CRED_RETRIEVED = 12,
  PD_EVENT_ENGINE_PONG = 13,
  PD_EVENT_LOG_LEVEL_SET = 14,
  PD_EVENT_LOG_BUFFER_RESULT = 15,
  PD_EVENT_ENGINE_LOG = 16,
  PD_EVENT_CALL_TRANSFER_BLIND_REQUESTED = 17,
  PD_EVENT_CALL_TRANSFER_ATTENDED_STARTED = 18,
  PD_EVENT_CALL_TRANSFER_ATTENDED_COMPLETED = 19,
  PD_EVENT_CALL_TRANSFER_STATUS = 20,
  PD_EVENT_RECORDING_STARTED = 45,
  PD_EVENT_RECORDING_STOPPED = 46,
  PD_EVENT_RECORDING_SAVED = 47,
  PD_EVENT_RECORDING_ERROR = 48,
};

VOIP_CORE_EXPORT int32_t engine_init(const char *user_agent);
VOIP_CORE_EXPORT int32_t engine_shutdown(void);
VOIP_CORE_EXPORT const char *engine_version(void);
VOIP_CORE_EXPORT void engine_set_event_callback(voip_core_event_callback_t cb);
VOIP_CORE_EXPORT int32_t engine_send_command(const char *cmd_type,
                                             const char *json_payload);

VOIP_CORE_EXPORT int32_t engine_register(const char *account_id,
                                         const char *user,
                                         const char *pass,
                                         const char *domain);
VOIP_CORE_EXPORT int32_t engine_unregister(const char *account_id);
VOIP_CORE_EXPORT int32_t engine_make_call(const char *account_id,
                                          const char *number);
VOIP_CORE_EXPORT int32_t engine_answer_call(void);
VOIP_CORE_EXPORT int32_t engine_hangup(void);
VOIP_CORE_EXPORT int32_t engine_set_mute(int32_t muted);
VOIP_CORE_EXPORT int32_t engine_set_hold(int32_t on_hold);
VOIP_CORE_EXPORT int32_t engine_send_dtmf(const char *digits);
VOIP_CORE_EXPORT int32_t engine_play_dtmf(const char *digits);
VOIP_CORE_EXPORT int32_t engine_start_recording(const char *file_path);
VOIP_CORE_EXPORT int32_t engine_stop_recording(void);
VOIP_CORE_EXPORT int32_t engine_is_recording(void);
VOIP_CORE_EXPORT int32_t engine_transfer_call(int32_t call_id,
                                              const char *dest_uri);
VOIP_CORE_EXPORT int32_t engine_start_attended_xfer(int32_t call_id,
                                                    const char *dest_uri);
VOIP_CORE_EXPORT int32_t engine_complete_xfer(int32_t call_a_id,
                                              int32_t call_b_id);
VOIP_CORE_EXPORT int32_t engine_merge_conference(int32_t call_a_id,
                                                 int32_t call_b_id);
VOIP_CORE_EXPORT int32_t engine_list_audio_devices(void);
VOIP_CORE_EXPORT int32_t engine_set_audio_devices(int32_t input_id,
                                                  int32_t output_id);
VOIP_CORE_EXPORT int32_t engine_set_log_level(const char *level);
VOIP_CORE_EXPORT int32_t engine_get_log_buffer(void);

#ifdef __cplusplus
}
#endif

#endif

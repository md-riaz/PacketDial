#include "voip_bridge.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static voip_event_callback_t g_callback = NULL;
static char g_last_account[64] = {0};
static char g_last_call[64] = {0};
static char g_last_remote[128] = {0};
static int g_call_counter = 0;
static int g_selected_input_id = 10;
static int g_selected_output_id = 21;
static int g_muted = 0;
static int g_held = 0;

static void emit_event(int32_t event_id, const char *payload);

static void emit_audio_devices(void) {
  emit_event(
      7,
      "{\"devices\":["
      "{\"id\":10,\"name\":\"Built-in microphone\",\"kind\":\"Input\"},"
      "{\"id\":11,\"name\":\"Bluetooth microphone\",\"kind\":\"Input\"},"
      "{\"id\":20,\"name\":\"Phone earpiece\",\"kind\":\"Output\"},"
      "{\"id\":21,\"name\":\"Speakerphone\",\"kind\":\"Output\"},"
      "{\"id\":22,\"name\":\"Bluetooth headset\",\"kind\":\"Output\"},"
      "{\"id\":23,\"name\":\"Wired headset\",\"kind\":\"Output\"}"
      "]}");
  char payload[128];
  snprintf(payload, sizeof(payload),
           "{\"selected_input\":%d,\"selected_output\":%d}",
           g_selected_input_id, g_selected_output_id);
  emit_event(8, payload);
}

static void emit_log_buffer(void) {
  emit_event(
      15,
      "{\"lines\":["
      "\"PacketDial native bridge booted\","
      "\"Audio devices enumerated\","
      "\"Diagnostics pipeline ready\""
      "],\"summary\":\"Native log buffer returned 3 lines\"}");
}

static void emit_call_state(const char *call_id, const char *state,
                            const char *account_id, const char *destination) {
  char payload[320];
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"state\":\"%s\",\"account_id\":\"%s\","
           "\"destination\":\"%s\"}",
           call_id == NULL ? "" : call_id, state == NULL ? "" : state,
           account_id == NULL ? "" : account_id,
           destination == NULL ? "" : destination);
  emit_event(4, payload);
}

static void emit_call_media(const char *call_id, int audio_active) {
  char payload[160];
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"audio_active\":%s}",
           call_id == NULL ? "" : call_id, audio_active ? "true" : "false");
  emit_event(5, payload);
}

static void emit_event(int32_t event_id, const char *payload) {
  if (g_callback != NULL) {
    g_callback(event_id, payload);
  }
}

static void emit_log(const char *level, const char *message) {
  char payload[256];
  snprintf(payload, sizeof(payload), "{\"level\":\"%s\",\"message\":\"%s\"}", level,
           message);
  emit_event(16, payload);
}

static void write_id(char *destination, int32_t destination_len, const char *value) {
  if (destination == NULL || destination_len <= 0) {
    return;
  }
  snprintf(destination, (size_t)destination_len, "%s", value);
}

FFI_PLUGIN_EXPORT int32_t voip_core_init(const char *json_config) {
  (void)json_config;
  emit_log("info", "Native stub initialized");
  emit_event(1, "{}");
  emit_audio_devices();
  emit_log_buffer();
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_core_shutdown(void) {
  emit_log("info", "Native stub shutdown");
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_core_set_event_callback(voip_event_callback_t cb) {
  g_callback = cb;
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_account_upsert(const char *json_account) {
  (void)json_account;
  emit_log("debug", "Account upsert accepted by native stub");
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_account_remove(const char *account_id) {
  if (account_id != NULL) {
    snprintf(g_last_account, sizeof(g_last_account), "%s", account_id);
  }
  emit_log("info", "Account removed from native stub");
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_account_register(const char *account_id) {
  char payload[256];
  snprintf(g_last_account, sizeof(g_last_account), "%s", account_id);
  snprintf(payload, sizeof(payload),
           "{\"account_id\":\"%s\",\"state\":\"registering\"}", account_id);
  emit_event(2, payload);
  snprintf(payload, sizeof(payload),
           "{\"account_id\":\"%s\",\"state\":\"registered\"}", account_id);
  emit_event(2, payload);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_account_unregister(const char *account_id) {
  char payload[256];
  snprintf(payload, sizeof(payload),
           "{\"account_id\":\"%s\",\"state\":\"unregistered\"}", account_id);
  emit_event(2, payload);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_start(
    const char *account_id,
    const char *destination,
    char *out_call_id,
    int32_t out_len) {
  char payload[256];
  g_call_counter += 1;
  snprintf(g_last_call, sizeof(g_last_call), "call-%03d", g_call_counter);
  snprintf(g_last_remote, sizeof(g_last_remote), "%s", destination);
  g_muted = 0;
  g_held = 0;
  write_id(out_call_id, out_len, g_last_call);

  emit_call_state(g_last_call, "connecting", account_id, destination);
  emit_call_media(g_last_call, 0);
  emit_call_state(g_last_call, "active", account_id, destination);
  emit_call_media(g_last_call, 1);
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"message\":\"Recording started for active call\"}",
           g_last_call);
  emit_event(45, payload);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_answer(const char *call_id) {
  emit_call_state(call_id, "active", g_last_account, g_last_remote);
  emit_call_media(call_id, 1);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_reject(const char *call_id) {
  emit_call_state(call_id, "ended", g_last_account, g_last_remote);
  emit_call_media(call_id, 0);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_hangup(const char *call_id) {
  char payload[320];
  emit_call_state(call_id, "ended", g_last_account, g_last_remote);
  emit_call_media(call_id, 0);
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"message\":\"Recording stopped\"}",
           call_id);
  emit_event(46, payload);
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"file_path\":\"packetdial_%s.wav\","
           "\"message\":\"Recording saved\"}",
           call_id, call_id == NULL ? "call" : call_id);
  emit_event(47, payload);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_set_mute(const char *call_id, int32_t muted) {
  char payload[256];
  g_muted = muted ? 1 : 0;
  snprintf(payload, sizeof(payload), "{\"level\":\"info\",\"message\":\"Mute %s for %s\"}",
           muted ? "enabled" : "disabled", call_id);
  emit_event(16, payload);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_set_hold(const char *call_id, int32_t hold) {
  g_held = hold ? 1 : 0;
  emit_call_state(call_id, hold ? "held" : "active", g_last_account,
                  g_last_remote);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_send_dtmf(const char *call_id, const char *digits) {
  char payload[256];
  snprintf(payload, sizeof(payload),
           "{\"level\":\"debug\",\"message\":\"Sent DTMF %s on %s\"}", digits, call_id);
  emit_event(16, payload);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_debug_simulate_incoming(
    const char *account_id,
    const char *remote_uri,
    const char *display_name) {
  char payload[256];
  g_call_counter += 1;
  snprintf(g_last_call, sizeof(g_last_call), "call-%03d", g_call_counter);
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"account_id\":\"%s\",\"remote_uri\":\"%s\",\"display_name\":\"%s\"}",
           g_last_call, account_id, remote_uri, display_name == NULL ? "" : display_name);
  emit_event(3, payload);
  emit_call_state(g_last_call, "ringing", account_id, remote_uri);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_transfer_blind(const char *call_id, const char *dest) {
  char payload[256];
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"destination\":\"%s\","
           "\"message\":\"Blind transfer requested\"}",
           call_id, dest);
  emit_event(17, payload);
  snprintf(payload, sizeof(payload),
           "{\"level\":\"info\",\"message\":\"Blind transfer %s to %s\"}", call_id, dest);
  emit_event(16, payload);
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"message\":\"Native transfer acknowledged\"}",
           call_id);
  emit_event(20, payload);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_transfer_attended_start(
    const char *call_id,
    const char *dest,
    char *out_consult_id,
    int32_t out_len) {
  char payload[256];
  char consult_id[64];
  g_call_counter += 1;
  snprintf(consult_id, sizeof(consult_id), "call-%03d", g_call_counter);
  write_id(out_consult_id, out_len, consult_id);
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"consult_call_id\":\"%s\","
           "\"destination\":\"%s\",\"message\":\"Attended transfer started\"}",
           call_id, consult_id, dest);
  emit_event(18, payload);
  snprintf(payload, sizeof(payload),
           "{\"level\":\"info\",\"message\":\"Attended transfer consult leg from %s to %s\"}",
           call_id, dest);
  emit_event(16, payload);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_call_transfer_attended_complete(
    const char *call_a,
    const char *call_b) {
  char payload[256];
  snprintf(payload, sizeof(payload),
           "{\"call_id\":\"%s\",\"consult_call_id\":\"%s\","
           "\"message\":\"Attended transfer completed\"}",
           call_a, call_b);
  emit_event(19, payload);
  snprintf(payload, sizeof(payload),
           "{\"level\":\"info\",\"message\":\"Attended transfer completed %s + %s\"}",
           call_a, call_b);
  emit_event(16, payload);
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_audio_set_route(int32_t route) {
  const char *route_name = "earpiece";
  switch (route) {
    case 1:
      route_name = "speaker";
      g_selected_output_id = 21;
      break;
    case 2:
      route_name = "bluetooth";
      g_selected_output_id = 22;
      break;
    case 3:
      route_name = "headset";
      g_selected_output_id = 23;
      break;
    default:
      route_name = "earpiece";
      g_selected_output_id = 20;
      break;
  }

  char payload[128];
  snprintf(payload, sizeof(payload), "{\"route\":\"%s\"}", route_name);
  emit_event(6, payload);
  emit_audio_devices();
  return 0;
}

FFI_PLUGIN_EXPORT int32_t voip_diag_export(
    const char *directory_path,
    char *out_file_path,
    int32_t out_len) {
  char full_path[512];
  FILE *file = NULL;
  int written = snprintf(
      full_path,
      sizeof(full_path),
      "%s/packetdial_diagnostics.txt",
      directory_path);
  if (written <= 0 || written >= (int)sizeof(full_path)) {
    return -1;
  }

  file = fopen(full_path, "w");
  if (file == NULL) {
    return -2;
  }

  fprintf(file, "PacketDial diagnostics export\n");
  fprintf(file, "mode=native_stub\n");
  fprintf(file, "last_account=%s\n", g_last_account);
  fprintf(file, "last_call=%s\n", g_last_call);
  fclose(file);

  write_id(out_file_path, out_len, full_path);
  char payload[640];
  snprintf(payload, sizeof(payload),
           "{\"success\":true,\"path\":\"%s\","
           "\"summary\":\"Native diagnostics exported\"}",
           full_path);
  emit_event(9, payload);
  emit_log("info", "Diagnostics exported by native stub");
  return 0;
}

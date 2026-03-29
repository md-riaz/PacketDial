#include "../../include/voip_core.h"
#include "../shim/pjsip_shim.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define PD_MAX_ACCOUNTS 16
#define PD_MAX_CREDENTIALS 32
#define PD_MAX_AUDIO_DEVICES 64
#define PD_NAME_SLOT_LEN 128
#define PD_VALUE_SLOT_LEN 256

typedef struct PacketDialAccount {
  char external_id[64];
  char username[64];
  char auth_username[64];
  char password[128];
  char domain[128];
  char display_name[128];
  char outbound_proxy[128];
  char stun_server[128];
  char turn_server[128];
  char transport[16];
  char dtmf_mode[32];
  char voicemail_number[64];
  int register_expires_seconds;
  int tls_enabled;
  int ice_enabled;
  int srtp_enabled;
  int publish_presence;
  int internal_acc_id;
  int configured;
  int registered;
} PacketDialAccount;

typedef struct PacketDialCredential {
  char key[96];
  char value[PD_VALUE_SLOT_LEN];
  int configured;
} PacketDialCredential;

static voip_core_event_callback_t g_event_callback = NULL;
static PacketDialAccount g_accounts[PD_MAX_ACCOUNTS];
static PacketDialCredential g_credentials[PD_MAX_CREDENTIALS];
static int g_current_call_id = -1;
static int g_current_recording_call_id = -1;
static int g_selected_input_id = -1;
static int g_selected_output_id = -1;
static char g_log_level[16] = "info";
static const char *k_version = "packetdial-android-port/0.1";

static int str_case_eq(const char *lhs, const char *rhs) {
  unsigned char left;
  unsigned char right;
  if (lhs == NULL || rhs == NULL) {
    return 0;
  }
  while (*lhs != '\0' && *rhs != '\0') {
    left = (unsigned char)*lhs++;
    right = (unsigned char)*rhs++;
    if (tolower(left) != tolower(right)) {
      return 0;
    }
  }
  return *lhs == '\0' && *rhs == '\0';
}

static void json_copy_escaped(char *dst, size_t dst_len, const char *src) {
  size_t offset = 0;
  const unsigned char *cursor =
      (const unsigned char *)(src == NULL ? "" : src);
  if (dst_len == 0) {
    return;
  }
  while (*cursor != '\0' && offset + 1 < dst_len) {
    unsigned char ch = *cursor++;
    if ((ch == '\\' || ch == '"') && offset + 2 < dst_len) {
      dst[offset++] = '\\';
      dst[offset++] = (char)ch;
    } else if (ch == '\n' && offset + 2 < dst_len) {
      dst[offset++] = '\\';
      dst[offset++] = 'n';
    } else if (ch == '\r' && offset + 2 < dst_len) {
      dst[offset++] = '\\';
      dst[offset++] = 'r';
    } else if (ch == '\t' && offset + 2 < dst_len) {
      dst[offset++] = '\\';
      dst[offset++] = 't';
    } else if (ch >= 32) {
      dst[offset++] = (char)ch;
    }
  }
  dst[offset] = '\0';
}

static int json_extract_string(const char *json, const char *key, char *out,
                               size_t out_len) {
  char pattern[64];
  const char *cursor;
  size_t offset = 0;
  int escaping = 0;
  if (json == NULL || key == NULL || out == NULL || out_len == 0) {
    return 0;
  }
  snprintf(pattern, sizeof(pattern), "\"%s\":\"", key);
  cursor = strstr(json, pattern);
  if (cursor == NULL) {
    out[0] = '\0';
    return 0;
  }
  cursor += strlen(pattern);
  while (*cursor != '\0' && offset + 1 < out_len) {
    char ch = *cursor++;
    if (escaping) {
      switch (ch) {
        case 'n':
          out[offset++] = '\n';
          break;
        case 'r':
          out[offset++] = '\r';
          break;
        case 't':
          out[offset++] = '\t';
          break;
        default:
          out[offset++] = ch;
          break;
      }
      escaping = 0;
      continue;
    }
    if (ch == '\\') {
      escaping = 1;
      continue;
    }
    if (ch == '"') {
      break;
    }
    out[offset++] = ch;
  }
  out[offset] = '\0';
  return offset > 0;
}

static int json_extract_int(const char *json, const char *key, int fallback) {
  char pattern[64];
  const char *cursor;
  int value = fallback;
  if (json == NULL || key == NULL) {
    return fallback;
  }
  snprintf(pattern, sizeof(pattern), "\"%s\":", key);
  cursor = strstr(json, pattern);
  if (cursor == NULL) {
    return fallback;
  }
  cursor += strlen(pattern);
  sscanf(cursor, "%d", &value);
  return value;
}

static int json_extract_bool(const char *json, const char *key, int fallback) {
  char pattern[64];
  const char *cursor;
  if (json == NULL || key == NULL) {
    return fallback;
  }
  snprintf(pattern, sizeof(pattern), "\"%s\":", key);
  cursor = strstr(json, pattern);
  if (cursor == NULL) {
    return fallback;
  }
  cursor += strlen(pattern);
  if (strncmp(cursor, "true", 4) == 0) {
    return 1;
  }
  if (strncmp(cursor, "false", 5) == 0) {
    return 0;
  }
  return fallback;
}

static int transport_id_for(const char *transport) {
  if (transport == NULL) {
    return 3;
  }
  if (str_case_eq(transport, "udp")) {
    return 0;
  }
  if (str_case_eq(transport, "tcp")) {
    return 1;
  }
  if (str_case_eq(transport, "tls")) {
    return 2;
  }
  return 3;
}

static void emit_json(int event_id, const char *json_payload) {
  if (g_event_callback != NULL) {
    g_event_callback(event_id, json_payload);
  }
}

static void emit_log_event(const char *level, const char *message) {
  char escaped_level[32];
  char escaped_message[1024];
  char payload[1024];
  json_copy_escaped(escaped_level, sizeof(escaped_level), level);
  json_copy_escaped(escaped_message, sizeof(escaped_message), message);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"EngineLog\",\"payload\":{\"level\":\"%s\",\"message\":\"%s\"}}",
           escaped_level[0] == '\0' ? "info" : escaped_level, escaped_message);
  emit_json(PD_EVENT_ENGINE_LOG, payload);
}

static PacketDialAccount *find_account_by_external_id(const char *account_id) {
  int i;
  if (account_id == NULL) {
    return NULL;
  }
  for (i = 0; i < PD_MAX_ACCOUNTS; ++i) {
    if (g_accounts[i].configured &&
        strcmp(g_accounts[i].external_id, account_id) == 0) {
      return &g_accounts[i];
    }
  }
  return NULL;
}

static PacketDialAccount *alloc_account_slot(const char *account_id) {
  int i;
  PacketDialAccount *slot = find_account_by_external_id(account_id);
  if (slot != NULL) {
    return slot;
  }
  for (i = 0; i < PD_MAX_ACCOUNTS; ++i) {
    if (!g_accounts[i].configured) {
      memset(&g_accounts[i], 0, sizeof(g_accounts[i]));
      snprintf(g_accounts[i].external_id, sizeof(g_accounts[i].external_id), "%s",
               account_id == NULL ? "" : account_id);
      g_accounts[i].internal_acc_id = -1;
      return &g_accounts[i];
    }
  }
  return NULL;
}

static PacketDialCredential *find_credential_by_key(const char *key) {
  int i;
  if (key == NULL) {
    return NULL;
  }
  for (i = 0; i < PD_MAX_CREDENTIALS; ++i) {
    if (g_credentials[i].configured &&
        strcmp(g_credentials[i].key, key) == 0) {
      return &g_credentials[i];
    }
  }
  return NULL;
}

static PacketDialCredential *alloc_credential_slot(const char *key) {
  int i;
  PacketDialCredential *slot = find_credential_by_key(key);
  if (slot != NULL) {
    return slot;
  }
  for (i = 0; i < PD_MAX_CREDENTIALS; ++i) {
    if (!g_credentials[i].configured) {
      memset(&g_credentials[i], 0, sizeof(g_credentials[i]));
      snprintf(g_credentials[i].key, sizeof(g_credentials[i].key), "%s",
               key == NULL ? "" : key);
      g_credentials[i].configured = 1;
      return &g_credentials[i];
    }
  }
  return NULL;
}

static void emit_account_security_event(const char *account_id,
                                        const char *message) {
  char escaped_message[256];
  char escaped_account_id[96];
  char payload[512];
  json_copy_escaped(escaped_message, sizeof(escaped_message), message);
  json_copy_escaped(escaped_account_id, sizeof(escaped_account_id), account_id);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"AccountSecurityUpdated\",\"payload\":{"
           "\"account_id\":\"%s\",\"message\":\"%s\"}}",
           escaped_account_id, escaped_message);
  emit_json(PD_EVENT_ACCOUNT_SECURITY_UPDATED, payload);
}

static void emit_credential_event(int event_id, const char *type, const char *key,
                                  const char *value) {
  char escaped_key[128];
  char escaped_value[PD_VALUE_SLOT_LEN * 2];
  char payload[1024];
  json_copy_escaped(escaped_key, sizeof(escaped_key), key);
  json_copy_escaped(escaped_value, sizeof(escaped_value), value);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"%s\",\"payload\":{\"key\":\"%s\",\"value\":\"%s\"}}",
           type, escaped_key, escaped_value);
  emit_json(event_id, payload);
}

static void emit_diagnostics_ready(const char *path, int success,
                                   const char *summary) {
  char escaped_path[512];
  char escaped_summary[256];
  char payload[1024];
  json_copy_escaped(escaped_path, sizeof(escaped_path), path);
  json_copy_escaped(escaped_summary, sizeof(escaped_summary), summary);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"DiagBundleReady\",\"payload\":{\"path\":\"%s\","
           "\"success\":%s,\"summary\":\"%s\"}}",
           escaped_path, success ? "true" : "false", escaped_summary);
  emit_json(PD_EVENT_DIAG_BUNDLE_READY, payload);
}

static void clear_account_slot(PacketDialAccount *slot) {
  if (slot != NULL) {
    memset(slot, 0, sizeof(*slot));
    slot->internal_acc_id = -1;
  }
}

static int handle_account_upsert_command(const char *json_payload) {
  char account_id[64];
  PacketDialAccount *slot;
  if (!json_extract_string(json_payload, "uuid", account_id, sizeof(account_id))) {
    return -1;
  }
  slot = alloc_account_slot(account_id);
  if (slot == NULL) {
    return -1;
  }
  slot->configured = 1;
  json_extract_string(json_payload, "username", slot->username,
                      sizeof(slot->username));
  json_extract_string(json_payload, "auth_username", slot->auth_username,
                      sizeof(slot->auth_username));
  json_extract_string(json_payload, "password", slot->password,
                      sizeof(slot->password));
  json_extract_string(json_payload, "domain", slot->domain, sizeof(slot->domain));
  json_extract_string(json_payload, "display_name", slot->display_name,
                      sizeof(slot->display_name));
  json_extract_string(json_payload, "sip_proxy", slot->outbound_proxy,
                      sizeof(slot->outbound_proxy));
  json_extract_string(json_payload, "stun_server", slot->stun_server,
                      sizeof(slot->stun_server));
  json_extract_string(json_payload, "turn_server", slot->turn_server,
                      sizeof(slot->turn_server));
  json_extract_string(json_payload, "transport", slot->transport,
                      sizeof(slot->transport));
  json_extract_string(json_payload, "dtmf_mode", slot->dtmf_mode,
                      sizeof(slot->dtmf_mode));
  json_extract_string(json_payload, "voicemail_number", slot->voicemail_number,
                      sizeof(slot->voicemail_number));
  slot->register_expires_seconds =
      json_extract_int(json_payload, "register_expires_seconds", 300);
  slot->tls_enabled = json_extract_bool(json_payload, "tls_enabled", 0);
  slot->ice_enabled = json_extract_bool(json_payload, "ice_enabled", 0);
  slot->srtp_enabled = json_extract_bool(json_payload, "srtp_enabled", 0);
  slot->publish_presence = json_extract_bool(json_payload, "publish_presence", 0);
  emit_account_security_event(account_id, "Account profile updated");
  return 0;
}

static int handle_account_delete_profile_command(const char *json_payload) {
  char account_id[64];
  PacketDialAccount *slot;
  if (!json_extract_string(json_payload, "uuid", account_id, sizeof(account_id))) {
    return -1;
  }
  slot = find_account_by_external_id(account_id);
  if (slot == NULL) {
    return -1;
  }
  if (slot->internal_acc_id >= 0) {
    pd_acc_remove(slot->internal_acc_id);
  }
  clear_account_slot(slot);
  emit_account_security_event(account_id, "Account profile deleted");
  return 0;
}

static int handle_credential_store_command(const char *json_payload) {
  char key[96];
  char value[PD_VALUE_SLOT_LEN];
  PacketDialCredential *slot;
  if (!json_extract_string(json_payload, "key", key, sizeof(key))) {
    return -1;
  }
  json_extract_string(json_payload, "value", value, sizeof(value));
  slot = alloc_credential_slot(key);
  if (slot == NULL) {
    return -1;
  }
  snprintf(slot->value, sizeof(slot->value), "%s", value);
  emit_credential_event(PD_EVENT_CRED_STORED, "CredStored", key, "");
  if (strncmp(key, "sip_password:", 13) == 0) {
    emit_account_security_event(key + 13, "Credential stored");
  }
  return 0;
}

static int handle_credential_retrieve_command(const char *json_payload) {
  char key[96];
  PacketDialCredential *slot;
  if (!json_extract_string(json_payload, "key", key, sizeof(key))) {
    return -1;
  }
  slot = find_credential_by_key(key);
  emit_credential_event(PD_EVENT_CRED_RETRIEVED, "CredRetrieved", key,
                        slot == NULL ? "" : slot->value);
  return slot == NULL ? -1 : 0;
}

static int handle_diag_export_command(const char *json_payload) {
  char directory_path[260];
  char bundle_path[320];
  FILE *bundle_file;
  size_t path_len;
  if (!json_extract_string(json_payload, "directory_path", directory_path,
                           sizeof(directory_path))) {
    return -1;
  }
  path_len = strlen(directory_path);
  snprintf(bundle_path, sizeof(bundle_path), "%s%spacketdial_diagnostics.txt",
           directory_path,
           (path_len > 0 && (directory_path[path_len - 1] == '\\' ||
                             directory_path[path_len - 1] == '/'))
               ? ""
               : "\\");
  bundle_file = fopen(bundle_path, "w");
  if (bundle_file == NULL) {
    emit_diagnostics_ready("", 0, "Failed to create diagnostics bundle");
    return -1;
  }
  fprintf(bundle_file, "PacketDial diagnostics\n");
  fprintf(bundle_file, "version=%s\n", k_version);
  fprintf(bundle_file, "log_level=%s\n", g_log_level);
  fprintf(bundle_file, "selected_input=%d\n", g_selected_input_id);
  fprintf(bundle_file, "selected_output=%d\n", g_selected_output_id);
  fclose(bundle_file);
  emit_diagnostics_ready(bundle_path, 1, "Native diagnostics exported");
  return 0;
}

static const char *registration_state_for(int expires, int status_code) {
  if (expires > 0 && status_code >= 200 && status_code < 300) {
    return "Registered";
  }
  if (status_code == 0) {
    return "Registering";
  }
  if (status_code >= 300) {
    return "Failed";
  }
  return "Unregistered";
}

static const char *call_state_for(int inv_state) {
  switch (inv_state) {
    case 1:
      return "Calling";
    case 2:
    case 3:
      return "Ringing";
    case 4:
      return "Connecting";
    case 5:
      return "Active";
    case 6:
      return "Ended";
    default:
      return "Idle";
  }
}

static void on_reg_state_cb(int acc_id, int expires, int status_code,
                            const char *reason) {
  char payload[1024];
  char escaped_reason[256];
  char escaped_account_id[96];
  int i;
  const char *external_id = "";
  for (i = 0; i < PD_MAX_ACCOUNTS; ++i) {
    if (g_accounts[i].configured && g_accounts[i].internal_acc_id == acc_id) {
      external_id = g_accounts[i].external_id;
      g_accounts[i].registered = expires > 0 ? 1 : 0;
      break;
    }
  }
  json_copy_escaped(escaped_reason, sizeof(escaped_reason), reason);
  json_copy_escaped(escaped_account_id, sizeof(escaped_account_id), external_id);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"RegistrationStateChanged\",\"payload\":{"
           "\"account_id\":\"%s\",\"state\":\"%s\",\"reason\":\"%s\","
           "\"status_code\":%d,\"expires\":%d}}",
           escaped_account_id, registration_state_for(expires, status_code),
           escaped_reason, status_code, expires);
  emit_json(PD_EVENT_REGISTRATION_STATE_CHANGED, payload);
}

static void on_incoming_call_cb(int acc_id, int call_id, const char *from_uri) {
  char payload[1024];
  char escaped_account_id[96];
  char escaped_uri[512];
  const char *external_id = "";
  int i;
  g_current_call_id = call_id;
  for (i = 0; i < PD_MAX_ACCOUNTS; ++i) {
    if (g_accounts[i].configured && g_accounts[i].internal_acc_id == acc_id) {
      external_id = g_accounts[i].external_id;
      break;
    }
  }
  json_copy_escaped(escaped_account_id, sizeof(escaped_account_id), external_id);
  json_copy_escaped(escaped_uri, sizeof(escaped_uri), from_uri);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"CallStateChanged\",\"payload\":{"
           "\"call_id\":%d,\"account_id\":\"%s\",\"uri\":\"%s\","
           "\"direction\":\"incoming\",\"state\":\"Ringing\"}}",
           call_id, escaped_account_id, escaped_uri);
  emit_json(PD_EVENT_CALL_STATE_CHANGED, payload);
}

static void on_call_state_cb(int call_id, int inv_state, int status_code) {
  char payload[512];
  g_current_call_id = call_id;
  snprintf(payload, sizeof(payload),
           "{\"type\":\"CallStateChanged\",\"payload\":{"
           "\"call_id\":%d,\"state\":\"%s\",\"status_code\":%d}}",
           call_id, call_state_for(inv_state), status_code);
  emit_json(PD_EVENT_CALL_STATE_CHANGED, payload);
}

static void on_call_media_cb(int call_id, int active) {
  char payload[256];
  snprintf(payload, sizeof(payload),
           "{\"type\":\"MediaStatsUpdated\",\"payload\":{"
           "\"call_id\":%d,\"audio_active\":%s}}",
           call_id, active ? "true" : "false");
  emit_json(PD_EVENT_MEDIA_STATS_UPDATED, payload);
}

static void on_log_cb(int level, const char *msg) {
  const char *text_level = "info";
  switch (level) {
    case 1:
      text_level = "error";
      break;
    case 2:
      text_level = "warn";
      break;
    case 3:
      text_level = "info";
      break;
    default:
      text_level = "debug";
      break;
  }
  emit_log_event(text_level, msg);
}

static void on_sip_msg_cb(int call_id, int is_tx, const char *msg) {
  char escaped_message[2048];
  char payload[2048];
  json_copy_escaped(escaped_message, sizeof(escaped_message), msg);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"SipMessageCaptured\",\"payload\":{"
           "\"call_id\":%d,\"direction\":\"%s\",\"message\":\"%s\"}}",
           call_id, is_tx ? "tx" : "rx", escaped_message);
  emit_json(PD_EVENT_SIP_MESSAGE_CAPTURED, payload);
}

static void on_transfer_status_cb(int call_id, int status_code,
                                  const char *reason, int is_final) {
  char payload[1024];
  char escaped_reason[256];
  json_copy_escaped(escaped_reason, sizeof(escaped_reason), reason);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"CallTransferStatus\",\"payload\":{"
           "\"call_id\":%d,\"status_code\":%d,\"reason\":\"%s\","
           "\"is_final\":%s,\"message\":\"Transfer status %d\"}}",
           call_id, status_code, escaped_reason, is_final ? "true" : "false",
           status_code);
  emit_json(PD_EVENT_CALL_TRANSFER_STATUS, payload);
}

static void on_blf_status_cb(const char *uri, int state, const char *activity) {
  char escaped_uri[512];
  char escaped_activity[256];
  char payload[1024];
  json_copy_escaped(escaped_uri, sizeof(escaped_uri), uri);
  json_copy_escaped(escaped_activity, sizeof(escaped_activity), activity);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"BlfStatus\",\"payload\":{"
           "\"uri\":\"%s\",\"state\":%d,\"activity\":\"%s\"}}",
           escaped_uri, state, escaped_activity);
  emit_json(26, payload);
}

static void emit_audio_devices_snapshot(void) {
  int ids[PD_MAX_AUDIO_DEVICES];
  int kinds[PD_MAX_AUDIO_DEVICES];
  char names[PD_MAX_AUDIO_DEVICES * PD_NAME_SLOT_LEN];
  char payload[8192];
  int offset = 0;
  int count = pd_aud_dev_list(PD_MAX_AUDIO_DEVICES, ids, names, PD_NAME_SLOT_LEN,
                              kinds);
  int i;

  if (count < 0) {
    emit_log_event("warn", "pd_aud_dev_list failed");
    return;
  }

  offset += snprintf(payload + offset, sizeof(payload) - (size_t)offset,
                     "{\"type\":\"AudioDeviceList\",\"payload\":{\"devices\":[");
  for (i = 0; i < count && offset < (int)sizeof(payload) - 256; ++i) {
    const char *kind = "Input";
    char *name_slot = names + (i * PD_NAME_SLOT_LEN);
    char escaped_name[PD_NAME_SLOT_LEN * 2];
    if (kinds[i] == 1) {
      kind = "Output";
    } else if (kinds[i] == 2) {
      kind = "Both";
    }
    json_copy_escaped(escaped_name, sizeof(escaped_name), name_slot);
    offset += snprintf(payload + offset, sizeof(payload) - (size_t)offset,
                       "%s{\"id\":%d,\"name\":\"%s\",\"kind\":\"%s\"}",
                       i == 0 ? "" : ",", ids[i], escaped_name, kind);
  }
  snprintf(payload + offset, sizeof(payload) - (size_t)offset,
           "],\"selected_input\":%d,\"selected_output\":%d}}",
           g_selected_input_id, g_selected_output_id);
  emit_json(PD_EVENT_AUDIO_DEVICE_LIST, payload);
}

VOIP_CORE_EXPORT int32_t engine_init(const char *user_agent) {
  int rc = pd_init(user_agent, NULL, on_reg_state_cb, on_incoming_call_cb,
                   on_call_state_cb, on_call_media_cb, on_log_cb, on_sip_msg_cb,
                   on_transfer_status_cb, on_blf_status_cb);
  if (rc == 0) {
    emit_json(PD_EVENT_ENGINE_READY,
              "{\"type\":\"EngineReady\",\"payload\":{\"ready\":true}}");
    engine_list_audio_devices();
  }
  return rc;
}

VOIP_CORE_EXPORT int32_t engine_shutdown(void) {
  g_current_call_id = -1;
  g_current_recording_call_id = -1;
  memset(g_accounts, 0, sizeof(g_accounts));
  memset(g_credentials, 0, sizeof(g_credentials));
  return pd_shutdown();
}

VOIP_CORE_EXPORT const char *engine_version(void) { return k_version; }

VOIP_CORE_EXPORT void engine_set_event_callback(voip_core_event_callback_t cb) {
  g_event_callback = cb;
}

VOIP_CORE_EXPORT int32_t engine_send_command(const char *cmd_type,
                                             const char *json_payload) {
  if (cmd_type == NULL) {
    return -1;
  }
  if (strcmp(cmd_type, "AccountUpsert") == 0) {
    return handle_account_upsert_command(json_payload);
  }
  if (strcmp(cmd_type, "AccountDeleteProfile") == 0) {
    return handle_account_delete_profile_command(json_payload);
  }
  if (strcmp(cmd_type, "AccountUnregister") == 0) {
    char account_id[64];
    if (!json_extract_string(json_payload, "uuid", account_id,
                             sizeof(account_id))) {
      return -1;
    }
    return engine_unregister(account_id);
  }
  if (strcmp(cmd_type, "CredStore") == 0) {
    return handle_credential_store_command(json_payload);
  }
  if (strcmp(cmd_type, "CredRetrieve") == 0) {
    return handle_credential_retrieve_command(json_payload);
  }
  if (strcmp(cmd_type, "DiagExportBundle") == 0) {
    return handle_diag_export_command(json_payload);
  }
  if (strcmp(cmd_type, "Ping") == 0) {
    emit_json(PD_EVENT_ENGINE_PONG,
              "{\"type\":\"EnginePong\",\"payload\":{\"ok\":true}}");
    return 0;
  }
  emit_log_event("debug", cmd_type);
  return -1;
}

VOIP_CORE_EXPORT int32_t engine_register(const char *account_id,
                                         const char *user,
                                         const char *pass,
                                         const char *domain) {
  char sip_uri[256];
  char registrar[256];
  PacketDialAccount *slot = alloc_account_slot(account_id);
  const char *resolved_user = user;
  const char *resolved_pass = pass;
  const char *resolved_domain = domain;
  if (slot == NULL) {
    return -1;
  }
  if ((resolved_user == NULL || resolved_user[0] == '\0') &&
      slot->username[0] != '\0') {
    resolved_user = slot->username;
  }
  if ((resolved_pass == NULL || resolved_pass[0] == '\0') &&
      slot->password[0] != '\0') {
    resolved_pass = slot->password;
  }
  if ((resolved_domain == NULL || resolved_domain[0] == '\0') &&
      slot->domain[0] != '\0') {
    resolved_domain = slot->domain;
  }
  if (resolved_user == NULL || resolved_pass == NULL || resolved_domain == NULL ||
      resolved_user[0] == '\0' || resolved_pass[0] == '\0' ||
      resolved_domain[0] == '\0') {
    return -1;
  }
  snprintf(slot->username, sizeof(slot->username), "%s", resolved_user);
  snprintf(slot->password, sizeof(slot->password), "%s", resolved_pass);
  snprintf(slot->domain, sizeof(slot->domain), "%s", resolved_domain);
  snprintf(sip_uri, sizeof(sip_uri), "sip:%s@%s", resolved_user, resolved_domain);
  snprintf(registrar, sizeof(registrar), "sip:%s", resolved_domain);
  if (slot->internal_acc_id >= 0) {
    pd_acc_remove(slot->internal_acc_id);
  }
  slot->internal_acc_id = pd_acc_add(
      sip_uri, registrar, resolved_user, resolved_pass,
      slot->auth_username[0] == '\0' ? resolved_user : slot->auth_username,
      slot->outbound_proxy[0] == '\0' ? NULL : slot->outbound_proxy,
      transport_id_for(slot->transport),
      slot->stun_server[0] == '\0' ? NULL : slot->stun_server,
      slot->publish_presence,
      slot->display_name[0] == '\0' ? resolved_user : slot->display_name);
  slot->configured = slot->internal_acc_id >= 0;
  slot->registered = slot->configured;
  return slot->internal_acc_id >= 0 ? 0 : -1;
}

VOIP_CORE_EXPORT int32_t engine_unregister(const char *account_id) {
  PacketDialAccount *slot = find_account_by_external_id(account_id);
  if (slot == NULL || slot->internal_acc_id < 0) {
    return -1;
  }
  slot->registered = 0;
  if (pd_acc_remove(slot->internal_acc_id) != 0) {
    return -1;
  }
  slot->internal_acc_id = -1;
  return 0;
}

VOIP_CORE_EXPORT int32_t engine_make_call(const char *account_id,
                                          const char *number) {
  PacketDialAccount *slot = find_account_by_external_id(account_id);
  int call_id;
  if (slot == NULL || slot->internal_acc_id < 0 || number == NULL) {
    return -1;
  }
  call_id = pd_call_make(slot->internal_acc_id, number);
  if (call_id >= 0) {
    g_current_call_id = call_id;
  }
  return call_id >= 0 ? 0 : -1;
}

VOIP_CORE_EXPORT int32_t engine_answer_call(void) {
  if (g_current_call_id < 0) {
    return -1;
  }
  return pd_call_answer(g_current_call_id);
}

VOIP_CORE_EXPORT int32_t engine_hangup(void) {
  if (g_current_call_id < 0) {
    return -1;
  }
  return pd_call_hangup(g_current_call_id);
}

VOIP_CORE_EXPORT int32_t engine_set_mute(int32_t muted) {
  if (g_current_call_id < 0) {
    return -1;
  }
  return pd_call_set_mute(g_current_call_id, muted ? 1 : 0);
}

VOIP_CORE_EXPORT int32_t engine_set_hold(int32_t on_hold) {
  if (g_current_call_id < 0) {
    return -1;
  }
  return pd_call_hold(g_current_call_id, on_hold ? 1 : 0);
}

VOIP_CORE_EXPORT int32_t engine_send_dtmf(const char *digits) {
  if (g_current_call_id < 0) {
    return -1;
  }
  return pd_call_send_dtmf(g_current_call_id, digits);
}

VOIP_CORE_EXPORT int32_t engine_play_dtmf(const char *digits) {
  return pd_aud_play_dtmf(digits);
}

VOIP_CORE_EXPORT int32_t engine_start_recording(const char *file_path) {
  int rc;
  if (g_current_call_id < 0) {
    return -1;
  }
  rc = pd_call_start_recording(g_current_call_id, file_path);
  if (rc == 0) {
    char escaped_path[512];
    char payload[512];
    g_current_recording_call_id = g_current_call_id;
    json_copy_escaped(escaped_path, sizeof(escaped_path), file_path);
    snprintf(payload, sizeof(payload),
             "{\"type\":\"RecordingStarted\",\"payload\":{\"call_id\":%d,"
             "\"file_path\":\"%s\"}}",
             g_current_recording_call_id, escaped_path);
    emit_json(PD_EVENT_RECORDING_STARTED, payload);
  }
  return rc;
}

VOIP_CORE_EXPORT int32_t engine_stop_recording(void) {
  int rc;
  if (g_current_recording_call_id < 0) {
    return -1;
  }
  rc = pd_call_stop_recording(g_current_recording_call_id);
  if (rc == 0) {
    char payload[256];
    snprintf(payload, sizeof(payload),
             "{\"type\":\"RecordingStopped\",\"payload\":{\"call_id\":%d}}",
             g_current_recording_call_id);
    emit_json(PD_EVENT_RECORDING_STOPPED, payload);
    g_current_recording_call_id = -1;
  }
  return rc;
}

VOIP_CORE_EXPORT int32_t engine_is_recording(void) {
  if (g_current_recording_call_id < 0) {
    return 0;
  }
  return pd_call_is_recording(g_current_recording_call_id);
}

VOIP_CORE_EXPORT int32_t engine_transfer_call(int32_t call_id,
                                              const char *dest_uri) {
  int rc = pd_call_transfer(call_id, dest_uri);
  if (rc == 0) {
    char payload[512];
    char escaped_dest[256];
    json_copy_escaped(escaped_dest, sizeof(escaped_dest), dest_uri);
    snprintf(payload, sizeof(payload),
             "{\"type\":\"CallTransferBlindRequested\",\"payload\":{"
             "\"call_id\":%d,\"destination\":\"%s\",\"message\":\"Blind transfer requested\"}}",
             call_id, escaped_dest);
    emit_json(PD_EVENT_CALL_TRANSFER_BLIND_REQUESTED, payload);
  }
  return rc;
}

VOIP_CORE_EXPORT int32_t engine_start_attended_xfer(int32_t call_id,
                                                    const char *dest_uri) {
  int consult_call_id = pd_call_start_attended_xfer(call_id, dest_uri);
  if (consult_call_id >= 0) {
    char payload[512];
    char escaped_dest[256];
    json_copy_escaped(escaped_dest, sizeof(escaped_dest), dest_uri);
    snprintf(payload, sizeof(payload),
             "{\"type\":\"CallTransferAttendedStarted\",\"payload\":{"
             "\"call_id\":%d,\"consult_call_id\":%d,\"destination\":\"%s\","
             "\"message\":\"Attended transfer consult leg started\"}}",
             call_id, consult_call_id, escaped_dest);
    emit_json(PD_EVENT_CALL_TRANSFER_ATTENDED_STARTED, payload);
  }
  return consult_call_id;
}

VOIP_CORE_EXPORT int32_t engine_complete_xfer(int32_t call_a_id,
                                              int32_t call_b_id) {
  int rc = pd_call_complete_xfer(call_a_id, call_b_id);
  if (rc == 0) {
    char payload[512];
    snprintf(payload, sizeof(payload),
             "{\"type\":\"CallTransferAttendedCompleted\",\"payload\":{"
             "\"call_id\":%d,\"consult_call_id\":%d,"
             "\"message\":\"Attended transfer completed\"}}",
             call_a_id, call_b_id);
    emit_json(PD_EVENT_CALL_TRANSFER_ATTENDED_COMPLETED, payload);
  }
  return rc;
}

VOIP_CORE_EXPORT int32_t engine_merge_conference(int32_t call_a_id,
                                                 int32_t call_b_id) {
  return pd_call_merge_conference(call_a_id, call_b_id);
}

VOIP_CORE_EXPORT int32_t engine_list_audio_devices(void) {
  int capture_id = -1;
  int playback_id = -1;
  pd_aud_get_devs(&capture_id, &playback_id);
  g_selected_input_id = capture_id;
  g_selected_output_id = playback_id;
  emit_audio_devices_snapshot();
  return 0;
}

VOIP_CORE_EXPORT int32_t engine_set_audio_devices(int32_t input_id,
                                                  int32_t output_id) {
  int rc = pd_aud_set_devs(input_id, output_id);
  if (rc == 0) {
    char payload[256];
    g_selected_input_id = input_id;
    g_selected_output_id = output_id;
    snprintf(payload, sizeof(payload),
             "{\"type\":\"AudioDevicesSet\",\"payload\":{"
             "\"selected_input\":%d,\"selected_output\":%d}}",
             input_id, output_id);
    emit_json(PD_EVENT_AUDIO_DEVICES_SET, payload);
  }
  return rc;
}

VOIP_CORE_EXPORT int32_t engine_set_log_level(const char *level) {
  char payload[256];
  snprintf(g_log_level, sizeof(g_log_level), "%s",
           level == NULL ? "info" : level);
  snprintf(payload, sizeof(payload),
           "{\"type\":\"LogLevelSet\",\"payload\":{\"level\":\"%s\"}}",
           g_log_level);
  emit_json(PD_EVENT_LOG_LEVEL_SET, payload);
  return 0;
}

VOIP_CORE_EXPORT int32_t engine_get_log_buffer(void) {
  char payload[1024];
  snprintf(payload, sizeof(payload),
           "{\"type\":\"LogBufferResult\",\"payload\":{\"lines\":["
           "\"voip_core module initialised\","
           "\"log level=%s\","
           "\"shared native core bootstrapped\"],"
           "\"summary\":\"Native log buffer returned 3 lines\"}}",
           g_log_level);
  emit_json(PD_EVENT_LOG_BUFFER_RESULT, payload);
  return 0;
}

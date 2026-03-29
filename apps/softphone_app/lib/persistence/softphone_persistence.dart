import 'dart:convert';
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:path_provider/path_provider.dart';

class SoftphonePersistence {
  Future<SoftphoneState?> load() async {
    final file = await _stateFile();
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;
    return SoftphoneState(
      accounts: ((data['accounts'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(_accountFromJson)
          .toList()),
      contacts: ((data['contacts'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(_contactFromJson)
          .toList()),
      history: ((data['history'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(_historyFromJson)
          .toList()),
      logs: (data['logs'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      settings: _settingsFromJson(
        (data['settings'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      diagnostics: _diagnosticsFromJson(
        (data['diagnostics'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      selectedAccountId: data['selectedAccountId'] as String?,
      dialPadText: data['dialPadText'] as String? ?? '',
      engineReady: false,
    );
  }

  Future<void> save(SoftphoneState state) async {
    final file = await _stateFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'accounts': state.accounts.map(_accountToJson).toList(),
        'contacts': state.contacts.map(_contactToJson).toList(),
      'history': state.history.map(_historyToJson).toList(),
        'logs': state.logs,
        'settings': _settingsToJson(state.settings),
        'diagnostics': _diagnosticsToJson(state.diagnostics),
        'selectedAccountId': state.selectedAccountId,
        'dialPadText': state.dialPadText,
      }),
    );
  }

  Future<File> _stateFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}softphone_state.json');
  }

  static Map<String, dynamic> _accountToJson(SipAccount account) {
    return <String, dynamic>{
      'id': account.id,
      'label': account.label,
      'username': account.username,
      'authUsername': account.authUsername,
      'domain': account.domain,
      'displayName': account.displayName,
      'passwordRef': account.passwordRef,
      'transport': account.transport.name,
      'registrationState': account.registrationState.name,
      'tlsEnabled': account.tlsEnabled,
      'iceEnabled': account.iceEnabled,
      'srtpEnabled': account.srtpEnabled,
      'registerExpiresSeconds': account.registerExpiresSeconds,
      'codecs': account.codecs,
      'dtmfMode': account.dtmfMode.name,
      'registrar': account.registrar,
      'outboundProxy': account.outboundProxy,
      'stunServer': account.stunServer,
      'turnServer': account.turnServer,
      'voicemailNumber': account.voicemailNumber,
      'lastError': account.lastError,
      'isDefault': account.isDefault,
    };
  }

  static SipAccount _accountFromJson(Map<String, dynamic> json) {
    return SipAccount(
      id: json['id'] as String,
      label: json['label'] as String,
      username: json['username'] as String,
      authUsername:
          json['authUsername'] as String? ?? json['username'] as String,
      domain: json['domain'] as String,
      displayName: json['displayName'] as String,
      passwordRef:
          json['passwordRef'] as String? ??
          'sip_password:${json['id'] as String}',
      transport: SipTransport.values.byName(
        json['transport'] as String? ?? SipTransport.tls.name,
      ),
      registrationState: RegistrationState.values.byName(
        json['registrationState'] as String? ??
            RegistrationState.unregistered.name,
      ),
      tlsEnabled: json['tlsEnabled'] as bool? ?? false,
      iceEnabled: json['iceEnabled'] as bool? ?? false,
      srtpEnabled: json['srtpEnabled'] as bool? ?? false,
      registerExpiresSeconds: json['registerExpiresSeconds'] as int? ?? 300,
      codecs:
          (json['codecs'] as List<dynamic>? ??
                  const <dynamic>['opus', 'pcmu', 'pcma'])
              .cast<String>(),
      dtmfMode: DtmfMode.values.byName(
        json['dtmfMode'] as String? ?? DtmfMode.rfc2833.name,
      ),
      registrar: json['registrar'] as String?,
      outboundProxy: json['outboundProxy'] as String?,
      stunServer: json['stunServer'] as String?,
      turnServer: json['turnServer'] as String?,
      voicemailNumber: json['voicemailNumber'] as String?,
      lastError: json['lastError'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _contactToJson(Contact contact) {
    return <String, dynamic>{
      'id': contact.id,
      'name': contact.name,
      'extension': contact.extension,
      'presence': contact.presence,
      'notes': contact.notes,
      'isFavorite': contact.isFavorite,
    };
  }

  static Contact _contactFromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      name: json['name'] as String,
      extension: json['extension'] as String,
      presence: json['presence'] as String? ?? 'Offline',
      notes: json['notes'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _historyToJson(CallHistoryEntry entry) {
    return <String, dynamic>{
      'id': entry.id,
      'accountId': entry.accountId,
      'accountLabel': entry.accountLabel,
      'remoteIdentity': entry.remoteIdentity,
      'displayName': entry.displayName,
      'direction': entry.direction.name,
      'endedAt': entry.endedAt.toIso8601String(),
      'durationMs': entry.duration.inMilliseconds,
      'wasAnswered': entry.wasAnswered,
      'result': entry.result.name,
      'note': entry.note,
      'tags': entry.tags,
    };
  }

  static CallHistoryEntry _historyFromJson(Map<String, dynamic> json) {
    return CallHistoryEntry(
      id: json['id'] as String,
      accountId: json['accountId'] as String? ?? '',
      accountLabel: json['accountLabel'] as String? ?? '',
      remoteIdentity: json['remoteIdentity'] as String,
      displayName: json['displayName'] as String?,
      direction: CallDirection.values.byName(
        json['direction'] as String? ?? CallDirection.outgoing.name,
      ),
      endedAt: DateTime.parse(json['endedAt'] as String),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      wasAnswered: json['wasAnswered'] as bool? ?? false,
      result: CallHistoryResult.values.byName(
        json['result'] as String? ?? CallHistoryResult.disconnected.name,
      ),
      note: json['note'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
    );
  }

  static Map<String, dynamic> _settingsToJson(AppSettings settings) {
    return <String, dynamic>{
      'startInTray': settings.startInTray,
      'keepAwakeDuringCall': settings.keepAwakeDuringCall,
      'enableDiagnosticsOverlay': settings.enableDiagnosticsOverlay,
      'preferTcp': settings.preferTcp,
      'defaultTransport': settings.defaultTransport.name,
      'enableIceByDefault': settings.enableIceByDefault,
      'enableSrtpByDefault': settings.enableSrtpByDefault,
      'preferSystemNotifications': settings.preferSystemNotifications,
    };
  }

  static AppSettings _settingsFromJson(Map<String, dynamic> json) {
    return AppSettings(
      startInTray: json['startInTray'] as bool? ?? true,
      keepAwakeDuringCall: json['keepAwakeDuringCall'] as bool? ?? true,
      enableDiagnosticsOverlay:
          json['enableDiagnosticsOverlay'] as bool? ?? false,
      preferTcp: json['preferTcp'] as bool? ?? false,
      defaultTransport: SipTransport.values.byName(
        json['defaultTransport'] as String? ?? SipTransport.tls.name,
      ),
      enableIceByDefault: json['enableIceByDefault'] as bool? ?? true,
      enableSrtpByDefault: json['enableSrtpByDefault'] as bool? ?? true,
      preferSystemNotifications:
          json['preferSystemNotifications'] as bool? ?? true,
    );
  }

  static Map<String, dynamic> _diagnosticsToJson(DiagnosticsBundle bundle) {
    return <String, dynamic>{
      'summary': bundle.summary,
      'facts': bundle.facts,
      'logs': bundle.logs,
      'sections': bundle.sections,
      'lastExportPath': bundle.lastExportPath,
    };
  }

  static DiagnosticsBundle _diagnosticsFromJson(Map<String, dynamic> json) {
    return DiagnosticsBundle(
      summary: json['summary'] as String? ?? 'Bridge not initialized yet.',
      facts: (json['facts'] as Map<String, dynamic>? ?? <String, dynamic>{})
          .map((key, value) => MapEntry(key, '$value')),
      logs: (json['logs'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      sections:
          (json['sections'] as Map<String, dynamic>? ?? <String, dynamic>{})
              .map(
                (key, value) => MapEntry(
                  key,
                  (value as List<dynamic>? ?? <dynamic>[]).cast<String>(),
                ),
              ),
      lastExportPath: json['lastExportPath'] as String?,
    );
  }
}

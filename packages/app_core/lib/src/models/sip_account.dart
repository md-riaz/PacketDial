import 'enums.dart';

class SipAccount {
  const SipAccount({
    required this.id,
    required this.label,
    required this.username,
    required this.authUsername,
    required this.domain,
    required this.displayName,
    required this.passwordRef,
    required this.transport,
    required this.registrationState,
    this.tlsEnabled = false,
    this.iceEnabled = false,
    this.srtpEnabled = false,
    this.registerExpiresSeconds = 300,
    this.codecs = const <String>['opus', 'pcmu', 'pcma'],
    this.dtmfMode = DtmfMode.rfc2833,
    this.registrar,
    this.outboundProxy,
    this.stunServer,
    this.turnServer,
    this.voicemailNumber,
    this.lastError,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String username;
  final String authUsername;
  final String domain;
  final String displayName;
  final String passwordRef;
  final SipTransport transport;
  final RegistrationState registrationState;
  final bool tlsEnabled;
  final bool iceEnabled;
  final bool srtpEnabled;
  final int registerExpiresSeconds;
  final List<String> codecs;
  final DtmfMode dtmfMode;
  final String? registrar;
  final String? outboundProxy;
  final String? stunServer;
  final String? turnServer;
  final String? voicemailNumber;
  final String? lastError;
  final bool isDefault;

  String get addressOfRecord => 'sip:$username@$domain';

  SipAccount copyWith({
    String? id,
    String? label,
    String? username,
    String? authUsername,
    String? domain,
    String? displayName,
    String? passwordRef,
    SipTransport? transport,
    RegistrationState? registrationState,
    bool? tlsEnabled,
    bool? iceEnabled,
    bool? srtpEnabled,
    int? registerExpiresSeconds,
    List<String>? codecs,
    DtmfMode? dtmfMode,
    String? registrar,
    String? outboundProxy,
    String? stunServer,
    String? turnServer,
    String? voicemailNumber,
    String? lastError,
    bool? isDefault,
  }) {
    return SipAccount(
      id: id ?? this.id,
      label: label ?? this.label,
      username: username ?? this.username,
      authUsername: authUsername ?? this.authUsername,
      domain: domain ?? this.domain,
      displayName: displayName ?? this.displayName,
      passwordRef: passwordRef ?? this.passwordRef,
      transport: transport ?? this.transport,
      registrationState: registrationState ?? this.registrationState,
      tlsEnabled: tlsEnabled ?? this.tlsEnabled,
      iceEnabled: iceEnabled ?? this.iceEnabled,
      srtpEnabled: srtpEnabled ?? this.srtpEnabled,
      registerExpiresSeconds:
          registerExpiresSeconds ?? this.registerExpiresSeconds,
      codecs: codecs ?? this.codecs,
      dtmfMode: dtmfMode ?? this.dtmfMode,
      registrar: registrar ?? this.registrar,
      outboundProxy: outboundProxy ?? this.outboundProxy,
      stunServer: stunServer ?? this.stunServer,
      turnServer: turnServer ?? this.turnServer,
      voicemailNumber: voicemailNumber ?? this.voicemailNumber,
      lastError: lastError,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

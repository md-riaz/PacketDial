/// Registration state for a SIP account.
enum RegistrationState {
  unregistered,
  registering,
  registered,
  failed;

  static RegistrationState fromString(String s) => switch (s) {
        'Registering' => RegistrationState.registering,
        'Registered' => RegistrationState.registered,
        'Failed' => RegistrationState.failed,
        _ => RegistrationState.unregistered,
      };

  String get label => switch (this) {
        RegistrationState.unregistered => 'Unregistered',
        RegistrationState.registering => 'Registering…',
        RegistrationState.registered => 'Registered',
        RegistrationState.failed => 'Failed',
      };
}

/// A SIP account configuration plus its live registration state.
class Account {
  final String uuid;
  final String accountName;
  final String displayName;
  final String server;
  final String sipProxy;
  final String username;
  final String authUsername;
  final String domain;
  final String password;
  final String transport;
  final String stunServer;
  final String turnServer;

  /// Use TLS transport (SIP over TLS / SIPS).
  final bool tlsEnabled;

  /// Require SRTP for media encryption.
  final bool srtpEnabled;
  final RegistrationState registrationState;
  final String failureReason;

  const Account({
    required this.uuid,
    required this.accountName,
    required this.displayName,
    required this.server,
    this.sipProxy = '',
    required this.username,
    this.authUsername = '',
    this.domain = '',
    required this.password,
    this.transport = 'udp',
    this.stunServer = '',
    this.turnServer = '',
    this.tlsEnabled = false,
    this.srtpEnabled = false,
    this.registrationState = RegistrationState.unregistered,
    this.failureReason = '',
  });

  Account copyWith({
    String? displayName,
    String? server,
    String? sipProxy,
    String? username,
    String? authUsername,
    String? domain,
    String? password,
    String? transport,
    String? stunServer,
    String? turnServer,
    bool? tlsEnabled,
    bool? srtpEnabled,
    RegistrationState? registrationState,
    String? failureReason,
  }) =>
      Account(
        uuid: uuid,
        accountName: accountName,
        displayName: displayName ?? this.displayName,
        server: server ?? this.server,
        sipProxy: sipProxy ?? this.sipProxy,
        username: username ?? this.username,
        authUsername: authUsername ?? this.authUsername,
        domain: domain ?? this.domain,
        password: password ?? this.password,
        transport: transport ?? this.transport,
        stunServer: stunServer ?? this.stunServer,
        turnServer: turnServer ?? this.turnServer,
        tlsEnabled: tlsEnabled ?? this.tlsEnabled,
        srtpEnabled: srtpEnabled ?? this.srtpEnabled,
        registrationState: registrationState ?? this.registrationState,
        failureReason: failureReason ?? this.failureReason,
      );
}

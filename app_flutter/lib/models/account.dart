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
  final String id;
  final String displayName;
  final String server;
  final String username;
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
    required this.id,
    required this.displayName,
    required this.server,
    required this.username,
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
    String? username,
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
        id: id,
        displayName: displayName ?? this.displayName,
        server: server ?? this.server,
        username: username ?? this.username,
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

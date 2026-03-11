import '../core/encryption_service.dart';

class AccountSchema {
  String uuid; // Hidden internal ID for engine
  String accountName; // User-facing friendly label
  String displayName;
  String server; // SIP Registrar
  String sipProxy; // Optional proxy
  String username; // User ID / Extension
  String authUsername; // Login ID (often same as username)
  String domain; // SIP Domain
  String password;
  String transport; // 'udp', 'tcp', 'tls'
  String stunServer;
  String turnServer;
  bool tlsEnabled;
  bool srtpEnabled;
  bool autoRegister;
  bool isSelected;
  bool isEnabled;

  AccountSchema({
    required this.uuid,
    required this.accountName,
    required this.displayName,
    required this.server,
    this.sipProxy = '',
    required this.username,
    required this.authUsername,
    this.domain = '',
    required this.password,
    this.transport = 'udp',
    this.stunServer = '',
    this.turnServer = '',
    this.tlsEnabled = false,
    this.srtpEnabled = false,
    this.autoRegister = true,
    this.isSelected = false,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'accountName': accountName,
      'displayName': displayName,
      'server': server,
      'sipProxy': sipProxy,
      'username': username,
      'authUsername': authUsername,
      'domain': domain,
      'password': EncryptionService.encrypt(password),
      'plain_pass': '', // Placeholder for manual overrides
      'transport': transport,
      'stunServer': stunServer,
      'turnServer': turnServer,
      'tlsEnabled': tlsEnabled,
      'srtpEnabled': srtpEnabled,
      'autoRegister': autoRegister,
      'isSelected': isSelected,
      'isEnabled': isEnabled,
    };
  }

  factory AccountSchema.fromJson(Map<String, dynamic> json) {
    // Check for "plain_pass" override
    final plainPass = json['plain_pass'] as String? ?? '';
    final finalPassword = plainPass.isNotEmpty
        ? plainPass
        : EncryptionService.decrypt(json['password'] as String? ?? '');

    return AccountSchema(
      uuid: json['uuid'] as String? ?? '',
      accountName: json['accountName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      server: json['server'] as String? ?? '',
      sipProxy: json['sipProxy'] as String? ?? '',
      username: json['username'] as String? ?? '',
      authUsername: json['authUsername'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      password: finalPassword,
      transport: json['transport'] as String? ?? 'udp',
      stunServer: json['stunServer'] as String? ?? '',
      turnServer: json['turnServer'] as String? ?? '',
      tlsEnabled: json['tlsEnabled'] as bool? ?? false,
      srtpEnabled: json['srtpEnabled'] as bool? ?? false,
      autoRegister: json['autoRegister'] as bool? ?? true,
      isSelected: json['isSelected'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}

import 'package:isar/isar.dart';

part 'account_schema.g.dart';

@collection
class AccountSchema {
  Id? id; // Isar internal ID

  @Index(unique: true, replace: true)
  late String uuid; // Hidden internal ID for engine

  late String accountName; // User-facing friendly label

  late String displayName;
  late String server; // SIP Registrar
  late String sipProxy; // Optional proxy
  late String username; // User ID / Extension
  late String authUsername; // Login ID (often same as username)
  late String domain; // SIP Domain
  late String password;
  late String transport; // 'udp', 'tcp', 'tls'
  late String stunServer;
  late String turnServer;
  late bool tlsEnabled;
  late bool srtpEnabled;
  late bool autoRegister;
  late bool isSelected;
  late bool isEnabled;

  // We don't persist registrationState as it's runtime-only

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'accountName': accountName,
      'displayName': displayName,
      'server': server,
      'sipProxy': sipProxy,
      'username': username,
      'authUsername': authUsername,
      'domain': domain,
      'password': password,
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

  static AccountSchema fromJson(Map<String, dynamic> json) {
    return AccountSchema()
      ..id = json['id'] as int?
      ..uuid = json['uuid'] as String? ?? ''
      ..accountName = json['accountName'] as String? ?? ''
      ..displayName = json['displayName'] as String? ?? ''
      ..server = json['server'] as String? ?? ''
      ..sipProxy = json['sipProxy'] as String? ?? ''
      ..username = json['username'] as String? ?? ''
      ..authUsername = json['authUsername'] as String? ?? ''
      ..domain = json['domain'] as String? ?? ''
      ..password = json['password'] as String? ?? ''
      ..transport = json['transport'] as String? ?? 'udp'
      ..stunServer = json['stunServer'] as String? ?? ''
      ..turnServer = json['turnServer'] as String? ?? ''
      ..tlsEnabled = json['tlsEnabled'] as bool? ?? false
      ..srtpEnabled = json['srtpEnabled'] as bool? ?? false
      ..autoRegister = json['autoRegister'] as bool? ?? true
      ..isSelected = json['isSelected'] as bool? ?? false
      ..isEnabled = json['isEnabled'] as bool? ?? true;
  }
}

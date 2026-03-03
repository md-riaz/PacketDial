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

  // We don't persist registrationState as it's runtime-only
}

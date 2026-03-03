import 'package:isar/isar.dart';

part 'account_schema.g.dart';

@collection
class AccountSchema {
  Id? id; // Isar internal ID

  @Index(unique: true, replace: true)
  late String accountId; // User-defined ID (e.g., "work", "home")

  late String displayName;
  late String server;
  late String username;
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

import 'package:isar/isar.dart';

part 'call_history_schema.g.dart';

@collection
class CallHistorySchema {
  Id? id;

  late String accountId;
  late String uri;
  late String direction; // 'incoming', 'outgoing'
  late DateTime timestamp;
  late int durationSeconds;

  // Professional SIP Semantics
  int? sipCode; // e.g. 200, 486, 603
  String? sipReason; // e.g. "OK", "Busy Here", "Decline"
  String?
      result; // 'Answered', 'Missed', 'Rejected', 'Busy', 'Failed', 'Answered Elsewhere', 'Cancelled'
}

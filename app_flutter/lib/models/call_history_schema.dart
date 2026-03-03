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
  late String status; // 'completed', 'missed', 'failed'
}

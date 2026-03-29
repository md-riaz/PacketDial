import 'enums.dart';

class CallHistoryEntry {
  const CallHistoryEntry({
    required this.id,
    required this.accountId,
    required this.accountLabel,
    required this.remoteIdentity,
    required this.direction,
    required this.endedAt,
    required this.duration,
    required this.wasAnswered,
    required this.result,
    this.note = '',
    this.tags = const <String>[],
    this.displayName,
  });

  final String id;
  final String accountId;
  final String accountLabel;
  final String remoteIdentity;
  final String? displayName;
  final CallDirection direction;
  final DateTime endedAt;
  final Duration duration;
  final bool wasAnswered;
  final CallHistoryResult result;
  final String note;
  final List<String> tags;
}

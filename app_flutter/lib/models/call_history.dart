/// A record of a completed call.
class CallHistoryEntry {
  final int callId;
  final String accountId;
  final String uri;
  final String direction;
  final int startedAt;
  final int endedAt;
  final int durationSecs;
  final String endState;

  const CallHistoryEntry({
    required this.callId,
    required this.accountId,
    required this.uri,
    required this.direction,
    required this.startedAt,
    required this.endedAt,
    required this.durationSecs,
    required this.endState,
  });

  factory CallHistoryEntry.fromMap(Map<String, dynamic> m) => CallHistoryEntry(
        callId: (m['call_id'] as num?)?.toInt() ?? 0,
        accountId: m['account_id'] as String? ?? '',
        uri: m['uri'] as String? ?? '',
        direction: m['direction'] as String? ?? '',
        startedAt: (m['started_at'] as num?)?.toInt() ?? 0,
        endedAt: (m['ended_at'] as num?)?.toInt() ?? 0,
        durationSecs: (m['duration_secs'] as num?)?.toInt() ?? 0,
        endState: m['end_state'] as String? ?? '',
      );

  /// Human-readable duration string (e.g. "1:23").
  String get durationLabel {
    final m = durationSecs ~/ 60;
    final s = durationSecs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class CallHistorySchema {
  String id;
  String accountId;
  String uri;
  String direction; // 'incoming', 'outgoing'
  DateTime timestamp;
  int durationSeconds;
  int? sipCode; // e.g. 200, 486, 603
  String? sipReason; // e.g. "OK", "Busy Here", "Decline"
  String?
      result; // 'Answered', 'Missed', 'Rejected', 'Busy', 'Failed', 'Answered Elsewhere', 'Cancelled'

  CallHistorySchema({
    required this.id,
    required this.accountId,
    required this.uri,
    required this.direction,
    required this.timestamp,
    this.durationSeconds = 0,
    this.sipCode,
    this.sipReason,
    this.result,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'uri': uri,
      'direction': direction,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
      'sipCode': sipCode,
      'sipReason': sipReason,
      'result': result,
    };
  }

  factory CallHistorySchema.fromJson(Map<String, dynamic> json) {
    return CallHistorySchema(
      id: json['id'] as String? ?? '',
      accountId: json['accountId'] as String? ?? '',
      uri: json['uri'] as String? ?? '',
      direction: json['direction'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      sipCode: json['sipCode'] as int?,
      sipReason: json['sipReason'] as String?,
      result: json['result'] as String?,
    );
  }
}

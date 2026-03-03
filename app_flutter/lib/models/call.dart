/// Direction of a SIP call.
enum CallDirection {
  outgoing,
  incoming;

  static CallDirection fromString(String s) =>
      s == 'Incoming' ? CallDirection.incoming : CallDirection.outgoing;
}

/// State of an active SIP call.
enum CallState {
  ringing,
  inCall,
  onHold,
  ended;

  static CallState fromString(String s) => switch (s) {
        'InCall' => CallState.inCall,
        'OnHold' => CallState.onHold,
        'Ended' => CallState.ended,
        _ => CallState.ringing,
      };

  String get label => switch (this) {
        CallState.ringing => 'Ringing',
        CallState.inCall => 'In Call',
        CallState.onHold => 'On Hold',
        CallState.ended => 'Ended',
      };
}

/// Represents an active (or recently ended) call.
class ActiveCall {
  final int callId;
  final String accountId;
  final String uri;
  final CallDirection direction;
  final CallState state;
  final bool muted;
  final bool onHold;
  final DateTime? startedAt;

  const ActiveCall({
    required this.callId,
    required this.accountId,
    required this.uri,
    required this.direction,
    required this.state,
    required this.muted,
    required this.onHold,
    this.startedAt,
  });

  ActiveCall copyWith({
    CallState? state,
    bool? muted,
    bool? onHold,
    DateTime? startedAt,
  }) =>
      ActiveCall(
        callId: callId,
        accountId: accountId,
        uri: uri,
        direction: direction,
        state: state ?? this.state,
        muted: muted ?? this.muted,
        onHold: onHold ?? this.onHold,
        startedAt: startedAt ?? this.startedAt,
      );
}

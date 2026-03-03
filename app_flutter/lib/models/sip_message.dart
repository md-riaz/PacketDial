/// A captured SIP message (request or response) from the PJSIP engine.
class SipMessage {
  /// "send" for outgoing, "recv" for incoming.
  final String direction;

  /// PJSIP call id (-1 or 0 for non-call messages like REGISTER).
  final int callId;

  /// The full raw SIP message text (sensitive headers already masked by Rust).
  final String raw;

  /// When the message was captured.
  final DateTime timestamp;

  const SipMessage({
    required this.direction,
    required this.callId,
    required this.raw,
    required this.timestamp,
  });

  factory SipMessage.fromMap(Map<String, dynamic> m) => SipMessage(
        direction: m['direction'] as String? ?? 'recv',
        callId: (m['call_id'] as num?)?.toInt() ?? -1,
        raw: m['raw'] as String? ?? '',
        timestamp: DateTime.now(),
      );

  /// Returns the first line of the SIP message (e.g. "REGISTER sip:..." or "SIP/2.0 200 OK").
  String get firstLine {
    final idx = raw.indexOf('\n');
    if (idx == -1) return raw;
    return raw.substring(0, idx).trim();
  }

  /// True if this is an outgoing (sent) message.
  bool get isSend => direction == 'send';
}

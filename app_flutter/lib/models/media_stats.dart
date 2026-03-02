/// Media quality statistics for an active call.
class MediaStats {
  final int callId;
  final double jitterMs;
  final double packetLossPct;
  final String codec;
  final int bitrateKbps;

  const MediaStats({
    required this.callId,
    required this.jitterMs,
    required this.packetLossPct,
    required this.codec,
    required this.bitrateKbps,
  });

  factory MediaStats.fromMap(Map<String, dynamic> m) => MediaStats(
        callId: (m['call_id'] as num?)?.toInt() ?? 0,
        jitterMs: (m['jitter_ms'] as num?)?.toDouble() ?? 0.0,
        packetLossPct: (m['packet_loss_pct'] as num?)?.toDouble() ?? 0.0,
        codec: m['codec'] as String? ?? '',
        bitrateKbps: (m['bitrate_kbps'] as num?)?.toInt() ?? 0,
      );
}

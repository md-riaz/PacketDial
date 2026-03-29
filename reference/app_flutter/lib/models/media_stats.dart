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

  /// Approximate MOS score (1–5) using a simplified E-model.
  /// Based on jitter and packet loss — good enough for a color indicator.
  double get mos {
    // R-factor starts at 93.2 (ideal G.711)
    double r = 93.2;
    // Jitter penalty: ~0.5 per ms above 10ms threshold
    final jitterPenalty = (jitterMs - 10.0).clamp(0.0, double.infinity) * 0.5;
    // Loss penalty: ~2.5 per percent
    final lossPenalty = packetLossPct * 2.5;
    r -= jitterPenalty + lossPenalty;
    r = r.clamp(0.0, 100.0);
    // Convert R to MOS: MOS = 1 + 0.035R + R*(R-60)*(100-R)*7e-6
    if (r <= 0) return 1.0;
    final mos = 1.0 + 0.035 * r + r * (r - 60) * (100 - r) * 7e-6;
    return mos.clamp(1.0, 5.0);
  }
}

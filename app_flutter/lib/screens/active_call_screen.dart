import 'package:flutter/material.dart';

import '../core/engine_channel.dart';
import '../models/call.dart';
import '../models/media_stats.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  final _channel = EngineChannel.instance;

  @override
  void initState() {
    super.initState();
    _channel.events.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _hangup(int callId) => _channel.engine.hangup();

  void _toggleMute(ActiveCall call) => _channel.engine.setMute(!call.muted);

  void _toggleHold(ActiveCall call) => _channel.engine.setHold(!call.onHold);

  void _showDevicePicker() {
    final devices = _channel.audioDevices;
    final inputs = devices.where((d) => d.isInput).toList();
    final outputs = devices.where((d) => d.isOutput).toList();
    int selIn = _channel.selectedInputId;
    int selOut = _channel.selectedOutputId;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Audio Devices'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Microphone',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              RadioGroup<int>(
                groupValue: selIn,
                onChanged: (v) {
                  if (v != null) setDlgState(() => selIn = v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: inputs
                      .map((d) => RadioListTile<int>(
                            value: d.id,
                            title: Text(d.name),
                            dense: true,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Speaker',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              RadioGroup<int>(
                groupValue: selOut,
                onChanged: (v) {
                  if (v != null) setDlgState(() => selOut = v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: outputs
                      .map((d) => RadioListTile<int>(
                            value: d.id,
                            title: Text(d.name),
                            dense: true,
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                // Use structured C ABI to set audio devices
                _channel.engine.setAudioDevices(selIn, selOut);
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final call = _channel.activeCall;
    final MediaStats? stats =
        call != null ? _channel.mediaStats[call.callId] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_input_component, size: 20),
            tooltip: 'Audio Output',
            onPressed: _showDevicePicker,
          ),
        ],
      ),
      body: call == null
          ? const Center(child: Text('Idle'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Icon(Icons.account_circle,
                      size: 48, color: Colors.indigo),
                  const SizedBox(height: 8),
                  Text(
                    call.uri,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        call.state.label,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (call.direction == CallDirection.incoming)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('INCOMING',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _compactButton(
                        icon: call.muted ? Icons.mic_off : Icons.mic,
                        label: call.muted ? 'Unmute' : 'Mute',
                        active: call.muted,
                        onTap: () => _toggleMute(call),
                      ),
                      _compactButton(
                        icon: call.onHold ? Icons.play_arrow : Icons.pause,
                        label: call.onHold ? 'Resume' : 'Hold',
                        active: call.onHold,
                        onTap: () => _toggleHold(call),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 140,
                    child: ElevatedButton.icon(
                      onPressed: () => _hangup(call.callId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.call_end, size: 18),
                      label: const Text('Hang Up'),
                    ),
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 24),
                    _MediaStatsCard(stats: stats),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _compactButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: active
              ? BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8))
              : null,
          child: Column(
            children: [
              Icon(icon, size: 24, color: active ? Colors.red : Colors.indigo),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: active ? Colors.red : null)),
            ],
          ),
        ),
      );
}

class _MediaStatsCard extends StatelessWidget {
  final MediaStats stats;
  const _MediaStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Media Quality',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _StatRow('Codec', stats.codec),
            _StatRow('Bitrate', '${stats.bitrateKbps} kbps'),
            _StatRow('Jitter', '${stats.jitterMs.toStringAsFixed(1)} ms'),
            _StatRow(
                'Packet Loss', '${stats.packetLossPct.toStringAsFixed(1)} %'),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

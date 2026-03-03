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
                value: selIn,
                onChanged: (v) => setDlgState(() => selIn = v),
                children: inputs
                    .map((d) => RadioListTile<int>(
                          value: d.id,
                          title: Text(d.name),
                          dense: true,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              const Text('Speaker',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              RadioGroup<int>(
                value: selOut,
                onChanged: (v) => setDlgState(() => selOut = v),
                children: outputs
                    .map((d) => RadioListTile<int>(
                          value: d.id,
                          title: Text(d.name),
                          dense: true,
                        ))
                    .toList(),
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
        title: const Text('Active Call'),
        actions: [
          IconButton(
            icon: const Icon(Icons.speaker),
            tooltip: 'Audio Devices',
            onPressed: _showDevicePicker,
          ),
        ],
      ),
      body: call == null
          ? const Center(child: Text('No active call.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.call, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    call.uri,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    call.state.label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (call.direction == CallDirection.incoming)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Chip(label: Text('Incoming call')),
                    ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _controlButton(
                        icon: call.muted ? Icons.mic_off : Icons.mic,
                        label: call.muted ? 'Unmute' : 'Mute',
                        color: call.muted ? Colors.red : null,
                        onTap: () => _toggleMute(call),
                      ),
                      _controlButton(
                        icon:
                            call.onHold ? Icons.play_arrow : Icons.pause,
                        label: call.onHold ? 'Resume' : 'Hold',
                        onTap: () => _toggleHold(call),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FloatingActionButton.extended(
                    onPressed: () => _hangup(call.callId),
                    backgroundColor: Colors.red,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Hang Up'),
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 32),
                    _MediaStatsCard(stats: stats),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 4),
              Text(label),
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
            _StatRow('Packet Loss',
                '${stats.packetLossPct.toStringAsFixed(1)} %'),
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
            Text(label,
                style: const TextStyle(color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

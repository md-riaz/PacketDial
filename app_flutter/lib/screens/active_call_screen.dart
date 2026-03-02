import 'package:flutter/material.dart';

import '../core/engine_channel.dart';
import '../models/call.dart';

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

  void _hangup(int callId) =>
      _channel.sendCommand('CallHangup', {'call_id': callId});

  void _toggleMute(ActiveCall call) =>
      _channel.sendCommand('CallMute', {'call_id': call.callId, 'muted': !call.muted});

  void _toggleHold(ActiveCall call) =>
      _channel.sendCommand('CallHold', {'call_id': call.callId, 'hold': !call.onHold});

  @override
  Widget build(BuildContext context) {
    final call = _channel.activeCall;
    return Scaffold(
      appBar: AppBar(title: const Text('Active Call')),
      body: call == null
          ? const Center(child: Text('No active call.'))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(label: const Text('Incoming call')),
                    ),
                  const SizedBox(height: 40),
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
                        icon: call.onHold ? Icons.play_arrow : Icons.pause,
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

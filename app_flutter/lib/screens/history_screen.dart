import 'package:flutter/material.dart';

import '../core/engine_channel.dart';
import '../models/call_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _channel = EngineChannel.instance;

  @override
  void initState() {
    super.initState();
    // Refresh on first load and whenever events arrive
    _channel.engine.queryCallHistory();
    _channel.events.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show newest calls first
    final history = _channel.callHistory.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _channel.engine.queryCallHistory(),
          ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('No call history yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _HistoryTile(entry: history[i]),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final CallHistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isOutgoing = entry.direction == 'Outgoing';
    final dirIcon = isOutgoing ? Icons.call_made : Icons.call_received;
    final dirColor = isOutgoing ? Colors.blue : Colors.green;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: dirColor.withAlpha(30),
        child: Icon(dirIcon, color: dirColor, size: 20),
      ),
      title: Text(
        entry.uri,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
          '${entry.accountId}  •  ${entry.direction}  •  ${entry.durationLabel}'),
      trailing: Text(
        entry.endState,
        style: TextStyle(
          color: entry.endState == 'Ended' ? Colors.grey : Colors.red,
          fontSize: 12,
        ),
      ),
    );
  }
}

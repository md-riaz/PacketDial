import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../core/account_service.dart';
import '../models/call_history_schema.dart';
import '../providers/engine_provider.dart';

final historyListProvider = FutureProvider<List<CallHistorySchema>>((ref) {
  final isar = ref.read(accountServiceProvider).isar;
  if (isar == null) return [];
  return isar.callHistorySchemas.where().sortByTimestampDesc().findAll();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyListProvider);

    // Refresh when engine events indicate a change
    ref.listen(engineEventsProvider, (prev, next) {
      final type = next.value?['type'];
      if (type == 'CallHistoryResult' || type == 'CallStateChanged') {
        ref.invalidate(historyListProvider);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, size: 20),
            tooltip: 'Clear History',
            onPressed: () async {
              final isar = ref.read(accountServiceProvider).isar;
              if (isar != null) {
                await isar.writeTxn(() => isar.callHistorySchemas.clear());
                ref.invalidate(historyListProvider);
              }
            },
          ),
        ],
      ),
      body: historyAsync.when(
        data: (history) => history.isEmpty
            ? const Center(child: Text('No call history yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: history.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _HistoryTile(entry: history[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final CallHistorySchema entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isOutgoing = entry.direction.toLowerCase() == 'outgoing';
    final dirIcon = isOutgoing ? Icons.call_made : Icons.call_received;
    final dirColor = isOutgoing ? Colors.blue : Colors.green;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: dirColor.withValues(alpha: 0.1),
        child: Icon(dirIcon, color: dirColor, size: 16),
      ),
      title: Text(
        entry.uri,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${entry.accountId}  •  ${entry.timestamp.toString().substring(0, 16)}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            entry.result ?? 'Ended',
            style: TextStyle(
              color: (entry.result == 'Answered') ? Colors.green : Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (entry.sipCode != null)
            Text(
              'SIP ${entry.sipCode}',
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

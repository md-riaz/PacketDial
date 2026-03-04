import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../core/sip_uri_utils.dart';
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
            icon: const Icon(Icons.delete_sweep_outlined,
                size: 20, color: AppTheme.textTertiary),
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
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: history.length,
                itemBuilder: (_, i) => _HistoryCard(entry: history[i]),
              ),
        loading: () => Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation(AppTheme.primary.withValues(alpha: 0.6)),
          ),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppTheme.errorRed)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.06),
            ),
            child: Icon(Icons.history_outlined,
                size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          const Text('No Call History',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text('Your call history will appear here',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textTertiary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final CallHistorySchema entry;
  const _HistoryCard({required this.entry});

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }

  String _formattedTime(DateTime dt) {
    return DateFormat.jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = entry.direction.toLowerCase() == 'outgoing';
    final dirIcon = isOutgoing ? Icons.call_made : Icons.call_received;
    final dirColor = isOutgoing ? AppTheme.primary : AppTheme.callGreen;
    final isAnswered = entry.result == 'Answered';

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline,
            color: AppTheme.errorRed, size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: AppTheme.glassCard(borderRadius: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // TODO: Pre-fill dialer with this number
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Direction icon with glow
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: dirColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: dirColor.withValues(alpha: 0.1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(dirIcon, color: dirColor, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Call info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SipUriUtils.friendlyName(entry.uri),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              _formattedTime(entry.timestamp),
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textTertiary),
                            ),
                            Container(
                              width: 3,
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.textTertiary
                                    .withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              _relativeTime(entry.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Result badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isAnswered
                                  ? AppTheme.callGreen
                                  : AppTheme.errorRed)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.result ?? 'Ended',
                          style: TextStyle(
                            color: isAnswered
                                ? AppTheme.callGreen
                                : AppTheme.errorRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (entry.sipCode != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'SIP ${entry.sipCode}',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.textTertiary.withValues(alpha: 0.5),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

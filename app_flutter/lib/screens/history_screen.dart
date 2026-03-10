import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../core/sip_uri_utils.dart';
import '../core/account_service.dart';
import '../models/call_history_schema.dart';
import '../providers/engine_provider.dart';

final historyListProvider = Provider<List<CallHistorySchema>>((ref) {
  final history = ref.watch(accountServiceProvider).getHistory();
  return history.reversed.toList(); // Most recent first
});

/// Provider for call statistics
final callStatsProvider = Provider<CallStats>((ref) {
  final history = ref.watch(accountServiceProvider).getHistory();
  if (history.isEmpty) {
    return CallStats.empty();
  }

  // Get all history entries from the last 30 days
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));

  final recentHistory =
      history.where((h) => h.timestamp.isAfter(thirtyDaysAgo)).toList();

  int totalCalls = recentHistory.length;
  int incomingCalls = 0;
  int outgoingCalls = 0;
  int answeredCalls = 0;
  int missedCalls = 0;
  int totalDurationSecs = 0;

  for (final entry in recentHistory) {
    final isOutgoing = entry.direction.toLowerCase() == 'outgoing';
    final isAnswered = entry.result == 'Answered';

    if (isOutgoing) {
      outgoingCalls++;
    } else {
      incomingCalls++;
    }

    if (isAnswered) {
      answeredCalls++;
      totalDurationSecs += entry.durationSeconds;
    } else {
      missedCalls++;
    }
  }

  return CallStats(
    totalCalls: totalCalls,
    incomingCalls: incomingCalls,
    outgoingCalls: outgoingCalls,
    answeredCalls: answeredCalls,
    missedCalls: missedCalls,
    totalDurationSecs: totalDurationSecs,
  );
});

/// Call statistics data class
class CallStats {
  final int totalCalls;
  final int incomingCalls;
  final int outgoingCalls;
  final int answeredCalls;
  final int missedCalls;
  final int totalDurationSecs;

  const CallStats({
    required this.totalCalls,
    required this.incomingCalls,
    required this.outgoingCalls,
    required this.answeredCalls,
    required this.missedCalls,
    required this.totalDurationSecs,
  });

  factory CallStats.empty() {
    return const CallStats(
      totalCalls: 0,
      incomingCalls: 0,
      outgoingCalls: 0,
      answeredCalls: 0,
      missedCalls: 0,
      totalDurationSecs: 0,
    );
  }

  String get formattedTotalDuration {
    final hours = totalDurationSecs ~/ 3600;
    final minutes = (totalDurationSecs % 3600) ~/ 60;
    final seconds = totalDurationSecs % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyListProvider);
    final stats = ref.watch(callStatsProvider);

    // Refresh when engine events indicate a change
    ref.listen(engineEventsProvider, (prev, next) {
      final type = next.value?['type'];
      if (type == 'CallHistoryResult' || type == 'CallStateChanged') {
        ref.invalidate(historyListProvider);
        ref.invalidate(callStatsProvider);
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
              await ref.read(accountServiceProvider).clearHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Call Statistics Summary
          _buildStatsSummary(stats),
          // History list
          Expanded(
            child: history.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: history.length,
                    itemBuilder: (_, i) => _HistoryCard(entry: history[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(CallStats stats) {
    if (stats.totalCalls == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, size: 18, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Last 30 Days',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'Total',
                value: stats.totalCalls.toString(),
                color: AppTheme.textPrimary,
              ),
              _StatItem(
                label: 'Incoming',
                value: stats.incomingCalls.toString(),
                color: AppTheme.callGreen,
                icon: Icons.call_received,
              ),
              _StatItem(
                label: 'Outgoing',
                value: stats.outgoingCalls.toString(),
                color: AppTheme.primary,
                icon: Icons.call_made,
              ),
              _StatItem(
                label: 'Answered',
                value: stats.answeredCalls.toString(),
                color: AppTheme.accent,
                icon: Icons.check_circle,
              ),
              _StatItem(
                label: 'Missed',
                value: stats.missedCalls.toString(),
                color: AppTheme.errorRed,
                icon: Icons.call_missed,
              ),
              _StatItem(
                label: 'Duration',
                value: stats.formattedTotalDuration,
                color: AppTheme.textSecondary,
                icon: Icons.schedule,
              ),
            ],
          ),
        ],
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppTheme.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
            onTap: () async {
              // Pre-fill dialer with this number
              // TODO: Navigate to dialer screen with the number pre-filled
              // This will be implemented when dialer screen navigation is added
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

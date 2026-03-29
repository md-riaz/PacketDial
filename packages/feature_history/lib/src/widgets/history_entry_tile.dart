import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

class HistoryEntryTile extends StatelessWidget {
  const HistoryEntryTile({super.key, required this.entry});

  final CallHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultColor = switch (entry.result) {
      CallHistoryResult.answered => theme.colorScheme.primary,
      CallHistoryResult.missed => theme.colorScheme.error,
      CallHistoryResult.rejected => theme.colorScheme.error,
      CallHistoryResult.busy => theme.colorScheme.tertiary,
      CallHistoryResult.cancelled => theme.colorScheme.outline,
      CallHistoryResult.failed => theme.colorScheme.error,
      CallHistoryResult.disconnected => theme.colorScheme.secondary,
    };

    final start = entry.endedAt.toLocal().subtract(entry.duration);
    final startedLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(start));
    final endedLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(entry.endedAt.toLocal()));
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatShortDate(entry.endedAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: resultColor.withValues(alpha: 0.14),
              foregroundColor: resultColor,
              child: Icon(
                entry.direction == CallDirection.outgoing
                    ? Icons.call_made
                    : Icons.call_received,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.displayName ?? entry.remoteIdentity,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Chip(
                        label: Text(entry.result.name.toUpperCase()),
                        side: BorderSide(
                          color: resultColor.withValues(alpha: 0.3),
                        ),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: resultColor,
                        ),
                        backgroundColor: resultColor.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.accountLabel} - ${entry.remoteIdentity}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateLabel - $startedLabel to $endedLabel - ${entry.duration.inSeconds}s',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (entry.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(entry.note),
                  ],
                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.tags
                          .map((tag) => Chip(label: Text(tag)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../state/history_view_state.dart';
import '../widgets/history_entry_tile.dart';
import '../widgets/history_filter_bar.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.entries});

  final List<CallHistoryEntry> entries;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryViewState _viewState = const HistoryViewState();

  @override
  Widget build(BuildContext context) {
    final accountLabels =
        widget.entries
            .map(
              (entry) => entry.accountLabel.isEmpty
                  ? entry.accountId
                  : entry.accountLabel,
            )
            .toSet()
            .toList()
          ..sort();
    final filtered = widget.entries.where(_viewState.matches).toList()
      ..sort((left, right) => right.endedAt.compareTo(left.endedAt));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recents',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${filtered.length} of ${widget.entries.length} calls shown',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        HistoryFilterBar(
          state: _viewState,
          accountLabels: accountLabels,
          onChanged: (value) {
            setState(() {
              _viewState = value;
            });
          },
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No calls match the current filters.'),
            ),
          ),
        ...filtered.map((entry) => HistoryEntryTile(entry: entry)),
      ],
    );
  }
}

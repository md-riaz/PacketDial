import 'package:flutter/material.dart';

import '../state/history_view_state.dart';

class HistoryFilterBar extends StatelessWidget {
  const HistoryFilterBar({
    super.key,
    required this.state,
    required this.accountLabels,
    required this.onChanged,
  });

  final HistoryViewState state;
  final List<String> accountLabels;
  final ValueChanged<HistoryViewState> onChanged;

  @override
  Widget build(BuildContext context) {
    final dropdownItems = <String>['All accounts', ...accountLabels.toSet()];
    final isNarrow = MediaQuery.sizeOf(context).width < 700;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: isNarrow ? double.infinity : 280,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search history',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => onChanged(state.copyWith(query: value)),
          ),
        ),
        SizedBox(
          width: isNarrow ? double.infinity : null,
          child: DropdownButton<String>(
            isExpanded: isNarrow,
            value: dropdownItems.contains(state.accountLabel)
                ? state.accountLabel
                : 'All accounts',
            items: dropdownItems
                .map(
                  (label) => DropdownMenuItem<String>(
                    value: label,
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              onChanged(state.copyWith(accountLabel: value));
            },
          ),
        ),
        ...[
          (HistoryDirectionFilter.all, 'All'),
          (HistoryDirectionFilter.incoming, 'Incoming'),
          (HistoryDirectionFilter.outgoing, 'Outgoing'),
        ].map(
          (item) => FilterChip(
            selected: state.direction == item.$1,
            label: Text(item.$2),
            onSelected: (_) => onChanged(state.copyWith(direction: item.$1)),
          ),
        ),
        ...[
          (HistoryResultFilter.all, 'Any result'),
          (HistoryResultFilter.answered, 'Answered'),
          (HistoryResultFilter.missed, 'Missed'),
          (HistoryResultFilter.rejected, 'Rejected'),
          (HistoryResultFilter.busy, 'Busy'),
          (HistoryResultFilter.cancelled, 'Cancelled'),
          (HistoryResultFilter.failed, 'Failed'),
          (HistoryResultFilter.disconnected, 'Disconnected'),
        ].map(
          (item) => FilterChip(
            selected: state.result == item.$1,
            label: Text(item.$2),
            onSelected: (_) => onChanged(state.copyWith(result: item.$1)),
          ),
        ),
      ],
    );
  }
}

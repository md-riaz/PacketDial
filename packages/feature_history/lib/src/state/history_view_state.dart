import 'package:app_core/app_core.dart';

enum HistoryDirectionFilter { all, incoming, outgoing }

enum HistoryResultFilter {
  all,
  answered,
  missed,
  rejected,
  busy,
  cancelled,
  failed,
  disconnected,
}

class HistoryViewState {
  const HistoryViewState({
    this.query = '',
    this.direction = HistoryDirectionFilter.all,
    this.result = HistoryResultFilter.all,
    this.accountLabel = 'All accounts',
  });

  final String query;
  final HistoryDirectionFilter direction;
  final HistoryResultFilter result;
  final String accountLabel;

  HistoryViewState copyWith({
    String? query,
    HistoryDirectionFilter? direction,
    HistoryResultFilter? result,
    String? accountLabel,
  }) {
    return HistoryViewState(
      query: query ?? this.query,
      direction: direction ?? this.direction,
      result: result ?? this.result,
      accountLabel: accountLabel ?? this.accountLabel,
    );
  }

  bool matches(CallHistoryEntry entry) {
    if (direction != HistoryDirectionFilter.all) {
      final expected = direction == HistoryDirectionFilter.incoming
          ? CallDirection.incoming
          : CallDirection.outgoing;
      if (entry.direction != expected) {
        return false;
      }
    }

    if (result != HistoryResultFilter.all && _resultFor(entry) != result) {
      return false;
    }

    if (accountLabel != 'All accounts' &&
        entry.accountLabel != accountLabel &&
        entry.accountId != accountLabel) {
      return false;
    }

    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return <String>[
      entry.remoteIdentity,
      entry.displayName ?? '',
      entry.accountLabel,
      entry.accountId,
      entry.note,
      entry.tags.join(' '),
      entry.result.name,
    ].any((value) => value.toLowerCase().contains(needle));
  }

  HistoryResultFilter _resultFor(CallHistoryEntry entry) {
    switch (entry.result) {
      case CallHistoryResult.answered:
        return HistoryResultFilter.answered;
      case CallHistoryResult.missed:
        return HistoryResultFilter.missed;
      case CallHistoryResult.rejected:
        return HistoryResultFilter.rejected;
      case CallHistoryResult.busy:
        return HistoryResultFilter.busy;
      case CallHistoryResult.cancelled:
        return HistoryResultFilter.cancelled;
      case CallHistoryResult.failed:
        return HistoryResultFilter.failed;
      case CallHistoryResult.disconnected:
        return HistoryResultFilter.disconnected;
    }
  }
}

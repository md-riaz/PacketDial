import '../models/active_call.dart';
import '../models/call_history_entry.dart';
import '../models/enums.dart';

class HistoryRepository {
  const HistoryRepository();

  CallHistoryEntry fromEndedCall({
    required ActiveCall call,
    required String accountLabel,
    required DateTime endedAt,
  }) {
    return CallHistoryEntry(
      id: call.id,
      accountId: call.accountId,
      accountLabel: accountLabel,
      remoteIdentity: call.remoteIdentity,
      displayName: call.displayName,
      direction: call.direction,
      endedAt: endedAt,
      duration: endedAt.difference(call.startedAt),
      wasAnswered:
          call.state == CallState.active || call.state == CallState.held,
      result: _resultFor(call),
    );
  }

  CallHistoryResult _resultFor(ActiveCall call) {
    if (call.state == CallState.active || call.state == CallState.held) {
      return CallHistoryResult.disconnected;
    }
    if (call.direction == CallDirection.incoming) {
      return CallHistoryResult.missed;
    }
    return CallHistoryResult.cancelled;
  }
}

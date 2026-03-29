import 'package:riverpod/riverpod.dart';

import '../models/active_call.dart';
import '../models/call_history_entry.dart';

class CallLedgerState {
  const CallLedgerState({
    required this.activeCall,
    required this.history,
  });

  final ActiveCall? activeCall;
  final List<CallHistoryEntry> history;

  CallLedgerState copyWith({
    ActiveCall? activeCall,
    bool clearActiveCall = false,
    List<CallHistoryEntry>? history,
  }) {
    return CallLedgerState(
      activeCall: clearActiveCall ? null : activeCall ?? this.activeCall,
      history: history ?? this.history,
    );
  }
}

class CallLedger extends StateNotifier<CallLedgerState> {
  CallLedger()
    : super(
        const CallLedgerState(
          activeCall: null,
          history: <CallHistoryEntry>[],
        ),
      );

  void setActiveCall(ActiveCall call) {
    state = state.copyWith(activeCall: call);
  }

  void clearActiveCall() {
    state = state.copyWith(clearActiveCall: true);
  }

  void updateActiveCall(ActiveCall Function(ActiveCall current) update) {
    final current = state.activeCall;
    if (current == null) {
      return;
    }
    state = state.copyWith(activeCall: update(current));
  }

  void prependHistory(CallHistoryEntry entry) {
    state = state.copyWith(
      history: <CallHistoryEntry>[entry, ...state.history],
    );
  }

  void replace(CallLedgerState nextState) {
    state = nextState;
  }

  CallLedgerState get snapshot => state;
}

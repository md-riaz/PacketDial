import 'package:riverpod/riverpod.dart';

import '../models/enums.dart';

class RegistrationLedgerEntry {
  const RegistrationLedgerEntry({
    required this.state,
    this.reason,
  });

  final RegistrationState state;
  final String? reason;

  RegistrationLedgerEntry copyWith({
    RegistrationState? state,
    String? reason,
  }) {
    return RegistrationLedgerEntry(
      state: state ?? this.state,
      reason: reason ?? this.reason,
    );
  }
}

class RegistrationLedger extends StateNotifier<Map<String, RegistrationLedgerEntry>> {
  RegistrationLedger() : super(const <String, RegistrationLedgerEntry>{});

  void upsert(
    String accountId, {
    required RegistrationState state,
    String? reason,
  }) {
    final nextState = <String, RegistrationLedgerEntry>{
      ...this.state,
      accountId: RegistrationLedgerEntry(state: state, reason: reason),
    };
    this.state = nextState;
  }

  void remove(String accountId) {
    if (!state.containsKey(accountId)) {
      return;
    }
    final next = <String, RegistrationLedgerEntry>{...state}..remove(accountId);
    state = next;
  }

  void replace(Map<String, RegistrationLedgerEntry> entries) {
    state = Map<String, RegistrationLedgerEntry>.unmodifiable(entries);
  }

  Map<String, RegistrationLedgerEntry> get snapshot => state;

  RegistrationLedgerEntry? entryFor(String accountId) => state[accountId];
}

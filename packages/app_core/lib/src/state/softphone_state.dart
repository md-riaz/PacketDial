import '../models/active_call.dart';
import '../models/app_settings.dart';
import '../models/call_history_entry.dart';
import '../models/contact.dart';
import '../models/diagnostics_bundle.dart';
import '../models/sip_account.dart';

class SoftphoneState {
  const SoftphoneState({
    required this.accounts,
    required this.contacts,
    required this.history,
    required this.logs,
    required this.settings,
    required this.diagnostics,
    this.selectedAccountId,
    this.activeCall,
    this.dialPadText = '',
    this.engineReady = false,
  });

  factory SoftphoneState.initial() {
    return const SoftphoneState(
      accounts: <SipAccount>[],
      contacts: <Contact>[],
      history: <CallHistoryEntry>[],
      logs: <String>[],
      settings: AppSettings(),
      diagnostics: DiagnosticsBundle(
        summary: 'Bridge not initialized yet.',
        facts: <String, String>{},
        logs: <String>[],
      ),
    );
  }

  final List<SipAccount> accounts;
  final List<Contact> contacts;
  final List<CallHistoryEntry> history;
  final List<String> logs;
  final AppSettings settings;
  final DiagnosticsBundle diagnostics;
  final String? selectedAccountId;
  final ActiveCall? activeCall;
  final String dialPadText;
  final bool engineReady;

  SipAccount? get selectedAccount {
    if (selectedAccountId == null) {
      return accounts.isEmpty ? null : accounts.first;
    }
    for (final account in accounts) {
      if (account.id == selectedAccountId) {
        return account;
      }
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  SoftphoneState copyWith({
    List<SipAccount>? accounts,
    List<Contact>? contacts,
    List<CallHistoryEntry>? history,
    List<String>? logs,
    AppSettings? settings,
    DiagnosticsBundle? diagnostics,
    String? selectedAccountId,
    ActiveCall? activeCall,
    bool clearActiveCall = false,
    String? dialPadText,
    bool? engineReady,
  }) {
    return SoftphoneState(
      accounts: accounts ?? this.accounts,
      contacts: contacts ?? this.contacts,
      history: history ?? this.history,
      logs: logs ?? this.logs,
      settings: settings ?? this.settings,
      diagnostics: diagnostics ?? this.diagnostics,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      activeCall: clearActiveCall ? null : activeCall ?? this.activeCall,
      dialPadText: dialPadText ?? this.dialPadText,
      engineReady: engineReady ?? this.engineReady,
    );
  }
}

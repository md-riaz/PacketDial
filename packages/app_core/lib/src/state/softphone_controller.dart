import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:voip_bridge/voip_bridge.dart';
import 'package:platform_services/platform_services.dart';

import '../models/app_settings.dart';
import '../models/active_call.dart';
import '../models/enums.dart';
import '../models/sip_account.dart';
import '../repositories/account_repository.dart';
import '../repositories/contact_repository.dart';
import 'call_ledger.dart';
import 'diagnostics_ledger.dart';
import 'log_ledger.dart';
import 'registration_ledger.dart';
import 'softphone_state.dart';
import '../usecases/seed_workspace_usecase.dart';
import '../usecases/sync_accounts_to_bridge_usecase.dart';
import '../utils/bridge_runtime_label.dart';
import 'voip_event_router.dart';

class SoftphoneController extends StateNotifier<SoftphoneState> {
  SoftphoneController(
    this._bridge,
    this._secretsStore,
    this._registrationLedger,
    this._callLedger,
    this._diagnosticsLedger,
    this._logLedger,
  ) : super(SoftphoneState.initial());

  final VoipBridge _bridge;
  final SecureSecretsStore _secretsStore;
  final RegistrationLedger _registrationLedger;
  final CallLedger _callLedger;
  final DiagnosticsLedger _diagnosticsLedger;
  final LogLedger _logLedger;
  final Uuid _uuid = const Uuid();
  final AccountRepository _accountRepository = const AccountRepository();
  final ContactRepository _contactRepository = const ContactRepository();
  late final SeedWorkspaceUseCase _seedWorkspaceUseCase = SeedWorkspaceUseCase(
    accountRepository: _accountRepository,
    contactRepository: _contactRepository,
  );
  late final SyncAccountsToBridgeUseCase _syncAccountsToBridgeUseCase =
      SyncAccountsToBridgeUseCase(bridge: _bridge, secretsStore: _secretsStore);
  late final VoipEventRouter _eventRouter = VoipEventRouter(
    registrationLedger: _registrationLedger,
    callLedger: _callLedger,
    diagnosticsLedger: _diagnosticsLedger,
    logLedger: _logLedger,
    accountLabelForId: _accountLabelForId,
    onEngineReady: _setEngineReady,
  );
  StreamSubscription<VoipEvent>? _eventsSub;
  bool _engineReady = false;

  void hydrate(SoftphoneState restoredState) {
    _engineReady = restoredState.engineReady;
    _registrationLedger.replace(<String, RegistrationLedgerEntry>{
      for (final account in restoredState.accounts)
        account.id: RegistrationLedgerEntry(
          state: account.registrationState,
          reason: account.lastError,
        ),
    });
    _callLedger.replace(
      CallLedgerState(
        activeCall: restoredState.activeCall,
        history: restoredState.history,
      ),
    );
    _diagnosticsLedger.replace(restoredState.diagnostics);
    _logLedger.replace(restoredState.logs);
    state = restoredState;
  }

  Future<void> bootstrap() async {
    if (_eventsSub != null) {
      return;
    }
    state = _seedWorkspaceUseCase.execute(state);

    _seedLedgersFromState(state);
    _diagnosticsLedger.updateSummary(
      'Workspace scaffolded. ${bridgeRuntimeLabel(_bridge)} attached.',
    );
    _diagnosticsLedger.putFact('Bridge mode', bridgeRuntimeLabel(_bridge));
    _diagnosticsLedger.putFact('Target platforms', 'Android, iOS, Windows');
    _diagnosticsLedger.putFact('State owner', 'Riverpod app shell');
    _diagnosticsLedger.putFact(
      'Incoming call simulation',
      _bridge.supportsIncomingCallSimulation ? 'Available' : 'Disabled',
    );
    if (!_bridge.isOperational && _bridge.availabilityIssue != null) {
      _diagnosticsLedger.putFact('Native engine', 'Unavailable');
      _diagnosticsLedger.putSection('Native engine', <String>[
        _bridge.availabilityIssue!,
      ]);
      _logLedger.prepend(_bridge.availabilityIssue!);
    }
    _diagnosticsLedger.prependLog('Bootstrap pending');
    _logLedger.prepend('Bootstrap pending');

    if (state.accounts.isNotEmpty) {
      final defaultAccount = state.accounts.first;
      final existingPassword = await _secretsStore.readSipPassword(
        defaultAccount.passwordRef,
      );
      if ((existingPassword ?? '').isEmpty) {
        await _secretsStore.writeSipPassword(
          defaultAccount.passwordRef,
          'packetdial-demo-password',
        );
      }
    }

    _eventsSub = _bridge.events.listen(_handleEvent);
    if (!_bridge.isOperational) {
      await _bridge.initialize(
        const VoipInitConfig(appName: 'PacketDial', logLevel: 'debug'),
      );
      _syncState();
      return;
    }
    await _bridge.initialize(
      const VoipInitConfig(appName: 'PacketDial', logLevel: 'debug'),
    );
    await _syncAccountsToBridgeUseCase.execute(state.accounts);
    _syncState();
  }

  Future<void> addAccount({
    required String label,
    required String username,
    required String authUsername,
    required String domain,
    required String displayName,
    required String password,
    required SipTransport transport,
    required bool tlsEnabled,
    required bool iceEnabled,
    required bool srtpEnabled,
    required String? outboundProxy,
    required String? stunServer,
    required String? turnServer,
    required int registerExpiresSeconds,
    required DtmfMode dtmfMode,
    required String? voicemailNumber,
    required List<String> codecs,
  }) async {
    if (password.isEmpty) {
      _logLedger.prepend('Refused to create account without a SIP password');
      _syncState();
      return;
    }

    final accountId = _uuid.v4();
    final passwordRef = 'sip_password:$accountId';
    final account = SipAccount(
      id: accountId,
      label: label,
      username: username,
      authUsername: authUsername,
      domain: domain,
      displayName: displayName,
      passwordRef: passwordRef,
      registrar: 'sip:$domain',
      transport: transport,
      registrationState: RegistrationState.unregistered,
      tlsEnabled: tlsEnabled,
      iceEnabled: iceEnabled,
      srtpEnabled: srtpEnabled,
      outboundProxy: _nullIfBlank(outboundProxy),
      stunServer: _nullIfBlank(stunServer),
      turnServer: _nullIfBlank(turnServer),
      registerExpiresSeconds: registerExpiresSeconds,
      dtmfMode: dtmfMode,
      voicemailNumber: _nullIfBlank(voicemailNumber),
      codecs: codecs,
    );

    await _secretsStore.writeSipPassword(passwordRef, password);

    await _bridge.addOrUpdateAccount(
      VoipAccount(
        id: account.id,
        displayName: account.displayName,
        username: account.username,
        authUsername: account.authUsername,
        domain: account.domain,
        registrar: account.registrar ?? 'sip:${account.domain}',
        transport: account.transport.name,
        outboundProxy: account.outboundProxy,
        tlsEnabled: account.tlsEnabled,
        iceEnabled: account.iceEnabled,
        srtpEnabled: account.srtpEnabled,
        stunServer: account.stunServer,
        turnServer: account.turnServer,
        registerExpiresSeconds: account.registerExpiresSeconds,
        codecs: account.codecs,
        dtmfMode: account.dtmfMode.name,
        voicemailNumber: account.voicemailNumber,
        password: password,
      ),
    );

    state = state.copyWith(
      accounts: <SipAccount>[...state.accounts, account],
      selectedAccountId: account.id,
    );
    _registrationLedger.upsert(account.id, state: account.registrationState);
    _logLedger.prepend('Added account ${account.label}');
    _syncState();
  }

  Future<void> toggleRegistration(String accountId) async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final account = state.accounts.firstWhere((item) => item.id == accountId);
    final storedPassword = await _secretsStore.readSipPassword(
      account.passwordRef,
    );
    if ((storedPassword ?? '').isEmpty) {
      state = state.copyWith(
        accounts: state.accounts
            .map(
              (item) => item.id == accountId
                  ? item.copyWith(lastError: 'Missing stored SIP password')
                  : item,
            )
            .toList(),
      );
      _logLedger.prepend('Account $accountId missing secure password');
      _syncState();
      return;
    }
    await _bridge.addOrUpdateAccount(
      VoipAccount(
        id: account.id,
        displayName: account.displayName,
        username: account.username,
        authUsername: account.authUsername,
        domain: account.domain,
        registrar: account.registrar ?? 'sip:${account.domain}',
        transport: account.transport.name,
        outboundProxy: account.outboundProxy,
        tlsEnabled: account.tlsEnabled,
        iceEnabled: account.iceEnabled,
        srtpEnabled: account.srtpEnabled,
        stunServer: account.stunServer,
        turnServer: account.turnServer,
        registerExpiresSeconds: account.registerExpiresSeconds,
        codecs: account.codecs,
        dtmfMode: account.dtmfMode.name,
        voicemailNumber: account.voicemailNumber,
        password: storedPassword,
      ),
    );
    if (account.registrationState == RegistrationState.registered) {
      await _bridge.unregisterAccount(accountId);
      _syncState();
      return;
    }
    state = state.copyWith(
      accounts: state.accounts
          .map(
            (item) =>
                item.id == accountId ? item.copyWith(lastError: null) : item,
          )
          .toList(),
    );
    await _bridge.registerAccount(accountId);
    _syncState();
  }

  void selectAccount(String? accountId) {
    state = state.copyWith(selectedAccountId: accountId);
  }

  void updateDialPad(String value) {
    state = state.copyWith(dialPadText: value);
  }

  Future<void> placeCall() async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final account = state.selectedAccount;
    final destination = state.dialPadText.trim();
    if (account == null || destination.isEmpty) {
      return;
    }

    final result = await _bridge.startCall(
      accountId: account.id,
      destination: destination,
    );
    if (result.accepted &&
        result.callId.isNotEmpty &&
        result.callId != 'pending') {
      _callLedger.setActiveCall(
        ActiveCall(
          id: result.callId,
          accountId: account.id,
          remoteIdentity: destination,
          displayName: destination,
          direction: CallDirection.outgoing,
          state: CallState.connecting,
          startedAt: DateTime.now(),
        ),
      );
      _syncState();
    }
  }

  Future<void> simulateIncomingCall() async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final account = state.selectedAccount;
    if (account == null) {
      return;
    }
    await _bridge.simulateIncomingCall(
      accountId: account.id,
      remoteUri: 'sip:2001@${account.domain}',
      displayName: 'Demo inbound',
    );
  }

  Future<void> answerIncoming() async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final call = state.activeCall;
    if (call == null) {
      return;
    }
    await _bridge.answerCall(call.id);
  }

  Future<void> rejectIncoming() async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final call = state.activeCall;
    if (call == null) {
      return;
    }
    await _bridge.rejectCall(call.id);
  }

  Future<void> hangup() async {
    if (!_requireOperationalBridge()) {
      return;
    }
    await _bridge.hangupCall(state.activeCall?.id ?? '');
  }

  Future<void> setMute(bool muted) async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final call = state.activeCall;
    if (call == null) {
      return;
    }
    await _bridge.setMute(call.id, muted);
    _callLedger.updateActiveCall((current) => current.copyWith(muted: muted));
    _syncState();
  }

  Future<void> setHold(bool onHold) async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final call = state.activeCall;
    if (call == null) {
      return;
    }
    await _bridge.setHold(call.id, onHold);
    _callLedger.updateActiveCall((current) => current.copyWith(onHold: onHold));
    _syncState();
  }

  Future<void> setAudioRoute(AudioRoute route) async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final call = state.activeCall;
    if (call == null) {
      return;
    }
    await _bridge.setAudioRoute(route.name);
  }

  Future<void> sendDtmf(String digits) async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final call = state.activeCall;
    if (call == null || digits.isEmpty) {
      return;
    }
    await _bridge.sendDtmf(call.id, digits);
    state = state.copyWith(dialPadText: '${state.dialPadText}$digits');
  }

  Future<void> exportDiagnostics(String directoryPath) async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final exportPath = await _bridge.exportDiagnostics(directoryPath);
    final exported = exportPath.isNotEmpty;
    final summary = exported
        ? 'Diagnostics exported.'
        : 'Diagnostics export requested, but the current native engine did not produce a bundle path.';
    final logLine = exported
        ? 'Diagnostics exported to $exportPath'
        : 'Diagnostics export requested, but no bundle path was returned';
    _diagnosticsLedger.updateSummary(summary);
    _diagnosticsLedger.putFact(
      'Last export',
      exported ? exportPath : 'Requested only',
    );
    if (exported) {
      _diagnosticsLedger.markExportPath(exportPath);
    }
    _diagnosticsLedger.prependLog(logLine);
    _diagnosticsLedger.prependSectionLine(
      'Diagnostics exports',
      exported
          ? 'Exported bundle: $exportPath'
          : 'Export requested without bundle path',
    );
    _logLedger.prepend(logLine);
    _syncState();
  }

  void updateSettings(AppSettings settings) {
    state = state.copyWith(settings: settings);
  }

  void updateConnectivityStatus(List<String> links) {
    final normalized = links.isEmpty ? const <String>['none'] : links;
    _diagnosticsLedger.putFact('Connectivity', normalized.join(', '));
    _diagnosticsLedger.putSection('Connectivity', <String>[
      'Active links: ${normalized.join(', ')}',
      'Link count: ${normalized.length}',
    ]);
    _syncState();
  }

  void updateBootstrapStatus({
    required bool permissionsReady,
    required bool notificationsReady,
    required bool audioReady,
    required bool desktopReady,
  }) {
    _diagnosticsLedger.putSection('Bootstrap', <String>[
      'Permissions: ${permissionsReady ? 'ready' : 'pending'}',
      'Notifications: ${notificationsReady ? 'ready' : 'pending'}',
      'Audio session: ${audioReady ? 'ready' : 'pending'}',
      'Desktop shell: ${desktopReady ? 'ready' : 'pending'}',
    ]);
    _diagnosticsLedger.putFact(
      'Bootstrap',
      desktopReady && audioReady && notificationsReady && permissionsReady
          ? 'Ready'
          : 'Partial',
    );
    _syncState();
  }

  Future<void> blindTransfer(String destination) async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final call = state.activeCall;
    if (call == null || destination.trim().isEmpty) {
      return;
    }
    await _bridge.blindTransfer(call.id, destination.trim());
    _logLedger.prepend('Blind transfer requested to ${destination.trim()}');
    _syncState();
  }

  Future<void> beginAttendedTransfer(String destination) async {
    if (!_requireOperationalBridge()) {
      return;
    }
    final call = state.activeCall;
    if (call == null || destination.trim().isEmpty) {
      return;
    }
    final session = await _bridge.beginAttendedTransfer(
      call.id,
      destination.trim(),
    );
    _logLedger.prepend(
      'Attended transfer started: ${session.consultCallId} -> ${destination.trim()}',
    );
    _syncState();
  }

  void _seedLedgersFromState(SoftphoneState source) {
    _registrationLedger.replace(<String, RegistrationLedgerEntry>{
      for (final account in source.accounts)
        account.id: RegistrationLedgerEntry(
          state: account.registrationState,
          reason: account.lastError,
        ),
    });
    _callLedger.replace(
      CallLedgerState(activeCall: source.activeCall, history: source.history),
    );
    _diagnosticsLedger.replace(source.diagnostics);
    _logLedger.replace(source.logs);
  }

  String _accountLabelForId(String accountId) {
    return _accountRepository.labelFor(state.accounts, accountId);
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _requireOperationalBridge() {
    if (_bridge.isOperational) {
      return true;
    }
    final reason = _bridge.availabilityIssue ?? 'Native bridge unavailable';
    _logLedger.prepend(reason);
    _diagnosticsLedger.putFact('Native engine', 'Unavailable');
    _diagnosticsLedger.prependSectionLine('Native engine', reason);
    _syncState();
    return false;
  }

  void _handleEvent(VoipEvent event) {
    _eventRouter.handle(event);
    _syncState();
  }

  void _setEngineReady(bool value) {
    _engineReady = value;
  }

  void _syncState() {
    final activeCall = _callLedger.snapshot.activeCall;
    final syncedAccounts = <SipAccount>[
      for (final account in state.accounts)
        (() {
          final registration = _registrationLedger.entryFor(account.id);
          if (registration == null) {
            return account;
          }
          return account.copyWith(
            registrationState: registration.state,
            lastError: registration.reason,
          );
        })(),
    ];

    state = state.copyWith(
      accounts: syncedAccounts,
      history: _callLedger.snapshot.history,
      logs: _logLedger.snapshot,
      diagnostics: _diagnosticsLedger.snapshot,
      activeCall: activeCall,
      clearActiveCall: activeCall == null,
      engineReady: _engineReady,
    );
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }
}

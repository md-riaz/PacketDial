import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_services/platform_services.dart';
import 'package:voip_bridge/voip_bridge.dart';

import '../bootstrap/app_services.dart';

final voipBridgeProvider = Provider<VoipBridge>((ref) {
  return ReferenceEngineVoipBridge.createPreferred();
});

final platformServicesProvider = Provider<PlatformServicesBundle>((ref) {
  return AppServices.instance;
});

final registrationLedgerProvider = Provider<RegistrationLedger>((ref) {
  final ledger = RegistrationLedger();
  ref.onDispose(ledger.dispose);
  return ledger;
});

final callLedgerProvider = Provider<CallLedger>((ref) {
  final ledger = CallLedger();
  ref.onDispose(ledger.dispose);
  return ledger;
});

final diagnosticsLedgerProvider = Provider<DiagnosticsLedger>((ref) {
  final ledger = DiagnosticsLedger();
  ref.onDispose(ledger.dispose);
  return ledger;
});

final logLedgerProvider = Provider<LogLedger>((ref) {
  final ledger = LogLedger();
  ref.onDispose(ledger.dispose);
  return ledger;
});

final softphoneControllerProvider =
    StateNotifierProvider<SoftphoneController, SoftphoneState>((ref) {
      return SoftphoneController(
        ref.watch(voipBridgeProvider),
        ref.watch(platformServicesProvider).secureStorage,
        ref.watch(registrationLedgerProvider),
        ref.watch(callLedgerProvider),
        ref.watch(diagnosticsLedgerProvider),
        ref.watch(logLedgerProvider),
      );
    });

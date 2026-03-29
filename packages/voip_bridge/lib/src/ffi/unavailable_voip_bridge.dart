import 'dart:async';

import '../api/models.dart';
import '../api/voip_bridge_contract.dart';

class UnavailableVoipBridge implements VoipBridge {
  UnavailableVoipBridge(this.reason);

  final String reason;
  final StreamController<VoipEvent> _events =
      StreamController<VoipEvent>.broadcast();

  @override
  bool get supportsIncomingCallSimulation => false;

  @override
  bool get isOperational => false;

  @override
  String? get availabilityIssue => reason;

  @override
  Stream<VoipEvent> get events => _events.stream;

  @override
  Future<void> initialize(VoipInitConfig config) async {
    _events.add(
      NativeLogEvent(
        level: 'error',
        message: reason,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> shutdown() async {}

  @override
  Future<void> addOrUpdateAccount(VoipAccount account) async {}

  @override
  Future<void> removeAccount(String accountId) async {}

  @override
  Future<void> registerAccount(String accountId) async {}

  @override
  Future<void> unregisterAccount(String accountId) async {}

  @override
  Future<CallStartResult> startCall({
    required String accountId,
    required String destination,
  }) async {
    return const CallStartResult(callId: '', accepted: false);
  }

  @override
  Future<void> answerCall(String callId) async {}

  @override
  Future<void> rejectCall(String callId) async {}

  @override
  Future<void> hangupCall(String callId) async {}

  @override
  Future<void> setMute(String callId, bool muted) async {}

  @override
  Future<void> setHold(String callId, bool onHold) async {}

  @override
  Future<void> sendDtmf(String callId, String digits) async {}

  @override
  Future<void> simulateIncomingCall({
    required String accountId,
    required String remoteUri,
    String? displayName,
  }) async {}

  @override
  Future<void> blindTransfer(String callId, String destination) async {}

  @override
  Future<AttendedTransferSession> beginAttendedTransfer(
    String callId,
    String destination,
  ) async {
    return const AttendedTransferSession(originalCallId: '', consultCallId: '');
  }

  @override
  Future<void> completeAttendedTransfer({
    required String originalCallId,
    required String consultCallId,
  }) async {}

  @override
  Future<void> setAudioRoute(String route) async {}

  @override
  Future<String> exportDiagnostics(String directoryPath) async {
    return '';
  }
}

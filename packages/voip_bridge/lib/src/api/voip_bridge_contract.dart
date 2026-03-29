import 'models.dart';

abstract class VoipBridge {
  bool get supportsIncomingCallSimulation;
  bool get isOperational;
  String? get availabilityIssue;

  Future<void> initialize(VoipInitConfig config);
  Future<void> shutdown();

  Future<void> addOrUpdateAccount(VoipAccount account);
  Future<void> removeAccount(String accountId);
  Future<void> registerAccount(String accountId);
  Future<void> unregisterAccount(String accountId);

  Future<CallStartResult> startCall({
    required String accountId,
    required String destination,
  });

  Future<void> answerCall(String callId);
  Future<void> rejectCall(String callId);
  Future<void> hangupCall(String callId);

  Future<void> setMute(String callId, bool muted);
  Future<void> setHold(String callId, bool onHold);
  Future<void> sendDtmf(String callId, String digits);
  Future<void> simulateIncomingCall({
    required String accountId,
    required String remoteUri,
    String? displayName,
  });

  Future<void> blindTransfer(String callId, String destination);
  Future<AttendedTransferSession> beginAttendedTransfer(
    String callId,
    String destination,
  );
  Future<void> completeAttendedTransfer({
    required String originalCallId,
    required String consultCallId,
  });

  Future<void> setAudioRoute(String route);
  Future<String> exportDiagnostics(String directoryPath);

  Stream<VoipEvent> get events;
}

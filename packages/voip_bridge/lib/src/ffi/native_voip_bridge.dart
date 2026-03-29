import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import '../api/models.dart';
import '../api/voip_bridge_contract.dart';
import 'native_bindings.dart';

class NativeVoipBridge implements VoipBridge {
  NativeVoipBridge._(this._bindings);

  factory NativeVoipBridge.load() {
    return NativeVoipBridge._(NativeBindings.load());
  }

  static NativeVoipBridge? _activeInstance;

  final NativeBindings _bindings;
  final StreamController<VoipEvent> _events =
      StreamController<VoipEvent>.broadcast();
  List<BridgeAudioDevice> _audioDevices = const <BridgeAudioDevice>[];
  int? _selectedInputId;
  int? _selectedOutputId;

  @override
  bool get supportsIncomingCallSimulation => true;

  @override
  bool get isOperational => true;

  @override
  String? get availabilityIssue => null;

  static final ffi.Pointer<ffi.NativeFunction<EventCallbackNative>>
  _callbackPointer = ffi.Pointer.fromFunction<EventCallbackNative>(
    _eventCallback,
  );

  @override
  Stream<VoipEvent> get events => _events.stream;

  @override
  Future<void> initialize(VoipInitConfig config) async {
    _activeInstance = this;
    _bindings.setEventCallback(_callbackPointer);
    final configPtr = jsonEncode(<String, String>{
      'app_name': config.appName,
      'log_level': config.logLevel,
    }).toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.init(configPtr);
    } finally {
      calloc.free(configPtr);
    }
  }

  @override
  Future<void> shutdown() async {
    _bindings.shutdown();
  }

  @override
  Future<void> addOrUpdateAccount(VoipAccount account) async {
    final payload = jsonEncode(<String, String>{
      'id': account.id,
      'display_name': account.displayName,
      'username': account.username,
      'domain': account.domain,
      'registrar': account.registrar,
      'transport': account.transport,
      if (account.password != null) 'password': account.password!,
    }).toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.accountUpsert(payload);
    } finally {
      calloc.free(payload);
    }
  }

  @override
  Future<void> removeAccount(String accountId) async {
    final ptr = accountId.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.accountRemove(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  Future<void> registerAccount(String accountId) async {
    final ptr = accountId.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.accountRegister(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  Future<void> unregisterAccount(String accountId) async {
    final ptr = accountId.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.accountUnregister(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  Future<CallStartResult> startCall({
    required String accountId,
    required String destination,
  }) async {
    final accountPtr = accountId.toNativeUtf8().cast<ffi.Char>();
    final destinationPtr = destination.toNativeUtf8().cast<ffi.Char>();
    final outCallId = calloc<ffi.Char>(128);
    try {
      final result = _bindings.callStart(
        accountPtr,
        destinationPtr,
        outCallId,
        128,
      );
      return CallStartResult(
        callId: outCallId.cast<Utf8>().toDartString(),
        accepted: result == 0,
      );
    } finally {
      calloc.free(accountPtr);
      calloc.free(destinationPtr);
      calloc.free(outCallId);
    }
  }

  @override
  Future<void> answerCall(String callId) async {
    final ptr = callId.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.callAnswer(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  Future<void> rejectCall(String callId) async {
    final ptr = callId.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.callReject(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  Future<void> hangupCall(String callId) async {
    final ptr = callId.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.callHangup(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  Future<void> setMute(String callId, bool muted) async {
    final ptr = callId.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.callSetMute(ptr, muted ? 1 : 0);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  Future<void> setHold(String callId, bool onHold) async {
    final ptr = callId.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.callSetHold(ptr, onHold ? 1 : 0);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  Future<void> sendDtmf(String callId, String digits) async {
    final callPtr = callId.toNativeUtf8().cast<ffi.Char>();
    final digitsPtr = digits.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.callSendDtmf(callPtr, digitsPtr);
    } finally {
      calloc.free(callPtr);
      calloc.free(digitsPtr);
    }
  }

  @override
  Future<void> simulateIncomingCall({
    required String accountId,
    required String remoteUri,
    String? displayName,
  }) async {
    final accountPtr = accountId.toNativeUtf8().cast<ffi.Char>();
    final remotePtr = remoteUri.toNativeUtf8().cast<ffi.Char>();
    final displayPtr = (displayName ?? remoteUri)
        .toNativeUtf8()
        .cast<ffi.Char>();
    try {
      _bindings.debugSimulateIncoming(accountPtr, remotePtr, displayPtr);
    } finally {
      calloc.free(accountPtr);
      calloc.free(remotePtr);
      calloc.free(displayPtr);
    }
  }

  @override
  Future<void> blindTransfer(String callId, String destination) async {
    final callPtr = callId.toNativeUtf8().cast<ffi.Char>();
    final destPtr = destination.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.callTransferBlind(callPtr, destPtr);
    } finally {
      calloc.free(callPtr);
      calloc.free(destPtr);
    }
    _events.add(
      TransferEvent(
        kind: TransferEventKind.blindRequested,
        callId: callId,
        destination: destination,
        message: 'Blind transfer requested',
      ),
    );
  }

  @override
  Future<AttendedTransferSession> beginAttendedTransfer(
    String callId,
    String destination,
  ) async {
    final callPtr = callId.toNativeUtf8().cast<ffi.Char>();
    final destPtr = destination.toNativeUtf8().cast<ffi.Char>();
    final outCallId = calloc<ffi.Char>(128);
    try {
      _bindings.callTransferAttendedStart(callPtr, destPtr, outCallId, 128);
      final session = AttendedTransferSession(
        originalCallId: callId,
        consultCallId: outCallId.cast<Utf8>().toDartString(),
      );
      _events.add(
        TransferEvent(
          kind: TransferEventKind.attendedStarted,
          callId: callId,
          consultCallId: session.consultCallId,
          destination: destination,
          message: 'Attended transfer consult leg started',
        ),
      );
      return session;
    } finally {
      calloc.free(callPtr);
      calloc.free(destPtr);
      calloc.free(outCallId);
    }
  }

  @override
  Future<void> completeAttendedTransfer({
    required String originalCallId,
    required String consultCallId,
  }) async {
    final originalPtr = originalCallId.toNativeUtf8().cast<ffi.Char>();
    final consultPtr = consultCallId.toNativeUtf8().cast<ffi.Char>();
    try {
      _bindings.callTransferAttendedComplete(originalPtr, consultPtr);
    } finally {
      calloc.free(originalPtr);
      calloc.free(consultPtr);
    }
    _events.add(
      TransferEvent(
        kind: TransferEventKind.attendedCompleted,
        callId: originalCallId,
        consultCallId: consultCallId,
        message: 'Attended transfer completed',
      ),
    );
  }

  @override
  Future<void> setAudioRoute(String route) async {
    final mapped = switch (route) {
      'speaker' => 1,
      'bluetooth' => 2,
      'headset' => 3,
      _ => 0,
    };
    _bindings.audioSetRoute(mapped);
  }

  @override
  Future<String> exportDiagnostics(String directoryPath) async {
    final directoryPtr = directoryPath.toNativeUtf8().cast<ffi.Char>();
    final outPathPtr = calloc<ffi.Char>(512);
    try {
      final result = _bindings.diagExport(directoryPtr, outPathPtr, 512);
      if (result != 0) {
        throw Exception('Native diagnostics export failed with code $result');
      }
      final path = outPathPtr.cast<Utf8>().toDartString();
      _events.add(
        DiagnosticsReportReady(
          success: path.isNotEmpty,
          summary: path.isNotEmpty
              ? 'Native diagnostics exported'
              : 'Native diagnostics export completed without a bundle path',
          path: path.isEmpty ? null : path,
        ),
      );
      return path;
    } finally {
      calloc.free(directoryPtr);
      calloc.free(outPathPtr);
    }
  }

  static void _eventCallback(int eventId, ffi.Pointer<ffi.Char> payload) {
    _activeInstance?._handleNativeEvent(
      eventId,
      payload.cast<Utf8>().toDartString(),
    );
  }

  void _handleNativeEvent(int eventId, String payload) {
    final decoded = payload.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(payload) as Map<String, dynamic>;

    switch (eventId) {
      case 1:
        _events.add(const EngineReady());
      case 2:
        _events.add(
          AccountRegistrationChanged(
            accountId: decoded['account_id'] as String? ?? '',
            state: _parseRegistrationState(decoded['state'] as String?),
            reason: decoded['reason'] as String?,
          ),
        );
      case 3:
        _events.add(
          IncomingCallEvent(
            callId: decoded['call_id'] as String? ?? '',
            accountId: decoded['account_id'] as String? ?? '',
            remoteUri: decoded['remote_uri'] as String? ?? '',
            displayName: decoded['display_name'] as String?,
          ),
        );
      case 4:
        _events.add(
          CallStateChanged(
            callId: decoded['call_id'] as String? ?? '',
            state: _parseCallState(decoded['state'] as String?),
          ),
        );
      case 5:
        _events.add(
          CallMediaChanged(
            callId: decoded['call_id'] as String? ?? '',
            audioActive: decoded['audio_active'] as bool? ?? false,
          ),
        );
      case 6:
        _events.add(
          AudioRouteChanged(
            route: _parseAudioRoute(decoded['route'] as String?),
          ),
        );
      case 7:
        _audioDevices = (decoded['devices'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(
              (device) => BridgeAudioDevice(
                id: (device['id'] as num?)?.toInt() ?? 0,
                name: device['name'] as String? ?? 'Unknown',
                kind: device['kind'] as String? ?? 'Unknown',
              ),
            )
            .toList(growable: false);
        _events.add(
          AudioDevicesChanged(
            devices: _audioDevices,
            selectedInputId: _selectedInputId,
            selectedOutputId: _selectedOutputId,
          ),
        );
      case 8:
        _selectedInputId = (decoded['selected_input'] as num?)?.toInt();
        _selectedOutputId = (decoded['selected_output'] as num?)?.toInt();
        _events.add(
          AudioDevicesChanged(
            devices: _audioDevices,
            selectedInputId: _selectedInputId,
            selectedOutputId: _selectedOutputId,
          ),
        );
      case 9:
        final path = decoded['path'] as String?;
        _events.add(
          DiagnosticsReportReady(
            success: decoded['success'] as bool? ?? (path?.isNotEmpty ?? false),
            summary:
                decoded['summary'] as String? ??
                'Native diagnostics export completed',
            path: path,
          ),
        );
      case 15:
        final lines = (decoded['lines'] as List<dynamic>? ?? const <dynamic>[])
            .map((line) => '$line')
            .toList(growable: false);
        _events.add(
          LogBufferReceived(
            lines: lines,
            summary: decoded['summary'] as String?,
          ),
        );
      case 17:
      case 18:
      case 19:
      case 20:
        _events.add(
          TransferEvent(
            kind: _parseTransferKind(eventId),
            callId: decoded['call_id'] as String? ?? '',
            consultCallId: decoded['consult_call_id'] as String?,
            destination: decoded['destination'] as String?,
            message: decoded['message'] as String?,
          ),
        );
      case 45:
      case 46:
      case 47:
      case 48:
        _events.add(
          RecordingEvent(
            kind: _parseRecordingKind(eventId),
            callId: decoded['call_id'] as String?,
            filePath: decoded['file_path'] as String?,
            message: decoded['message'] as String?,
          ),
        );
      case 16:
        _events.add(
          NativeLogEvent(
            level: decoded['level'] as String? ?? 'info',
            message: decoded['message'] as String? ?? payload,
            timestamp: DateTime.now(),
          ),
        );
    }
  }

  BridgeRegistrationState _parseRegistrationState(String? value) {
    return switch (value) {
      'registering' => BridgeRegistrationState.registering,
      'registered' => BridgeRegistrationState.registered,
      'failed' => BridgeRegistrationState.failed,
      _ => BridgeRegistrationState.unregistered,
    };
  }

  BridgeCallState _parseCallState(String? value) {
    return switch (value) {
      'ringing' => BridgeCallState.ringing,
      'connecting' => BridgeCallState.connecting,
      'active' => BridgeCallState.active,
      'held' => BridgeCallState.held,
      'ended' => BridgeCallState.ended,
      _ => BridgeCallState.idle,
    };
  }

  BridgeAudioRoute _parseAudioRoute(String? value) {
    return switch (value) {
      'speaker' => BridgeAudioRoute.speaker,
      'bluetooth' => BridgeAudioRoute.bluetooth,
      'headset' => BridgeAudioRoute.headset,
      _ => BridgeAudioRoute.earpiece,
    };
  }

  TransferEventKind _parseTransferKind(int eventId) {
    return switch (eventId) {
      17 => TransferEventKind.blindRequested,
      18 => TransferEventKind.attendedStarted,
      19 => TransferEventKind.attendedCompleted,
      _ => TransferEventKind.status,
    };
  }

  RecordingEventKind _parseRecordingKind(int eventId) {
    return switch (eventId) {
      45 => RecordingEventKind.started,
      46 => RecordingEventKind.stopped,
      47 => RecordingEventKind.saved,
      _ => RecordingEventKind.error,
    };
  }
}

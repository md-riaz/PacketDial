import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../api/models.dart';
import '../api/voip_bridge_contract.dart';
import 'unavailable_voip_bridge.dart';

typedef _RefEventCallbackNative =
    ffi.Void Function(ffi.Int32 eventId, ffi.Pointer<ffi.Char> payload);

class _AudioDeviceEntry {
  const _AudioDeviceEntry({
    required this.id,
    required this.name,
    required this.kind,
  });

  final int id;
  final String name;
  final String kind;

  bool get isInput => kind.toLowerCase() == 'input';
  bool get isOutput => kind.toLowerCase() == 'output';
}

class ReferenceEngineVoipBridge implements VoipBridge {
  ReferenceEngineVoipBridge._(ffi.DynamicLibrary library)
    : _engineInit = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('engine_init'),
      _engineVersion = library
          .lookupFunction<
            ffi.Pointer<ffi.Char> Function(),
            ffi.Pointer<ffi.Char> Function()
          >('engine_version'),
      _engineShutdown = library
          .lookupFunction<ffi.Int32 Function(), int Function()>(
            'engine_shutdown',
          ),
      _engineRegister = library
          .lookupFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
            ),
            int Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
            )
          >('engine_register'),
      _engineUnregister = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('engine_unregister'),
      _engineMakeCall = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)
          >('engine_make_call'),
      _engineAnswerCall = library
          .lookupFunction<ffi.Int32 Function(), int Function()>(
            'engine_answer_call',
          ),
      _engineHangup = library
          .lookupFunction<ffi.Int32 Function(), int Function()>(
            'engine_hangup',
          ),
      _engineSetMute = library
          .lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>(
            'engine_set_mute',
          ),
      _engineSetHold = library
          .lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>(
            'engine_set_hold',
          ),
      _engineSendDtmf = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('engine_send_dtmf'),
      _engineTransferCall = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Int32, ffi.Pointer<ffi.Char>),
            int Function(int, ffi.Pointer<ffi.Char>)
          >('engine_transfer_call'),
      _engineStartAttendedXfer = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Int32, ffi.Pointer<ffi.Char>),
            int Function(int, ffi.Pointer<ffi.Char>)
          >('engine_start_attended_xfer'),
      _engineCompleteXfer = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Int32, ffi.Int32),
            int Function(int, int)
          >('engine_complete_xfer'),
      _engineListAudioDevices = library
          .lookupFunction<ffi.Int32 Function(), int Function()>(
            'engine_list_audio_devices',
          ),
      _engineSetLogLevel = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('engine_set_log_level'),
      _engineGetLogBuffer = library
          .lookupFunction<ffi.Int32 Function(), int Function()>(
            'engine_get_log_buffer',
          ),
      _engineSetAudioDevices = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Int32, ffi.Int32),
            int Function(int, int)
          >('engine_set_audio_devices'),
      _engineSendCommand = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)
          >('engine_send_command'),
      _engineSetEventCallback = library
          .lookupFunction<
            ffi.Void Function(
              ffi.Pointer<ffi.NativeFunction<_RefEventCallbackNative>>,
            ),
            void Function(
              ffi.Pointer<ffi.NativeFunction<_RefEventCallbackNative>>,
            )
          >('engine_set_event_callback');

  static ReferenceEngineVoipBridge? tryLoad() {
    final dllPath = _resolveReferenceDll();
    if (dllPath == null) {
      return null;
    }
    try {
      return ReferenceEngineVoipBridge._(ffi.DynamicLibrary.open(dllPath));
    } catch (_) {
      return null;
    }
  }

  static VoipBridge createPreferred() {
    final bridge = tryLoad();
    if (bridge != null) {
      return bridge;
    }
    return UnavailableVoipBridge(_platformLoadFailureMessage());
  }

  static String _platformLoadFailureMessage() {
    if (Platform.isWindows) {
      return 'PacketDial could not load the vendored Windows native engine (voip_core.dll).';
    }
    if (Platform.isAndroid) {
      return 'PacketDial could not load libvoip_core.so. Ensure the Android app packages the native engine under android/app/src/main/jniLibs/<abi>/libvoip_core.so.';
    }
    if (Platform.isIOS) {
      return 'PacketDial could not resolve the iOS native engine. Link a voip_core framework or static library into the Runner target.';
    }
    return 'PacketDial has no native engine available for ${Platform.operatingSystem}.';
  }

  static String? _resolveReferenceDll() {
    if (Platform.isAndroid) {
      return 'libvoip_core.so';
    }
    if (Platform.isIOS) {
      return null;
    }
    if (Platform.isWindows) {
      final executableDir = File(Platform.resolvedExecutable).parent.path;
      final candidates = <String>[
        '${Directory.current.path}${Platform.pathSeparator}voip_core.dll',
        '${Directory.current.path}${Platform.pathSeparator}native${Platform.pathSeparator}vendor${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}voip_core.dll',
        '${Directory.current.path}${Platform.pathSeparator}apps${Platform.pathSeparator}softphone_app${Platform.pathSeparator}windows${Platform.pathSeparator}vendor${Platform.pathSeparator}voip_core.dll',
        '$executableDir${Platform.pathSeparator}voip_core.dll',
        '$executableDir${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}native${Platform.pathSeparator}vendor${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}voip_core.dll',
      ];

      for (final candidate in candidates) {
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
    }
    return null;
  }

  static ReferenceEngineVoipBridge? _activeInstance;
  static final ffi.Pointer<ffi.NativeFunction<_RefEventCallbackNative>>
  _callbackPointer = ffi.Pointer.fromFunction<_RefEventCallbackNative>(
    _eventCallback,
  );

  final int Function(ffi.Pointer<ffi.Char>) _engineInit;
  final ffi.Pointer<ffi.Char> Function() _engineVersion;
  final int Function() _engineShutdown;
  final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  )
  _engineRegister;
  final int Function(ffi.Pointer<ffi.Char>) _engineUnregister;
  final int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)
  _engineMakeCall;
  final int Function() _engineAnswerCall;
  final int Function() _engineHangup;
  final int Function(int) _engineSetMute;
  final int Function(int) _engineSetHold;
  final int Function(ffi.Pointer<ffi.Char>) _engineSendDtmf;
  final int Function(int, ffi.Pointer<ffi.Char>) _engineTransferCall;
  final int Function(int, ffi.Pointer<ffi.Char>) _engineStartAttendedXfer;
  final int Function(int, int) _engineCompleteXfer;
  final int Function() _engineListAudioDevices;
  final int Function(ffi.Pointer<ffi.Char>) _engineSetLogLevel;
  final int Function() _engineGetLogBuffer;
  final int Function(int, int) _engineSetAudioDevices;
  final int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)
  _engineSendCommand;
  final void Function(ffi.Pointer<ffi.NativeFunction<_RefEventCallbackNative>>)
  _engineSetEventCallback;

  final StreamController<VoipEvent> _events =
      StreamController<VoipEvent>.broadcast();
  final Map<String, VoipAccount> _accounts = <String, VoipAccount>{};
  final Map<String, Completer<String?>> _credentialWaiters =
      <String, Completer<String?>>{};
  Completer<String?>? _diagnosticsExportWaiter;
  Completer<String>? _pendingOutgoingCallId;
  List<_AudioDeviceEntry> _audioDevices = const <_AudioDeviceEntry>[];
  int _selectedInputId = 0;
  int _selectedOutputId = 1;

  @override
  Stream<VoipEvent> get events => _events.stream;

  @override
  bool get supportsIncomingCallSimulation => false;

  @override
  bool get isOperational => true;

  @override
  String? get availabilityIssue => null;

  @override
  Future<void> initialize(VoipInitConfig config) async {
    _activeInstance = this;
    _engineSetEventCallback(_callbackPointer);
    final userAgent = config.appName.toNativeUtf8().cast<ffi.Char>();
    final logLevel = config.logLevel.toNativeUtf8().cast<ffi.Char>();
    try {
      _engineInit(userAgent);
      _engineSetLogLevel(logLevel);
    } finally {
      calloc.free(userAgent);
      calloc.free(logLevel);
    }

    final versionPtr = _engineVersion();
    if (versionPtr != ffi.nullptr) {
      _events.add(
        NativeLogEvent(
          level: 'info',
          message:
              'Native engine loaded: ${versionPtr.cast<Utf8>().toDartString()}',
          timestamp: DateTime.now(),
        ),
      );
    }
    _engineListAudioDevices();
    _engineGetLogBuffer();
  }

  @override
  Future<void> shutdown() async {
    _engineShutdown();
  }

  @override
  Future<void> addOrUpdateAccount(VoipAccount account) async {
    _accounts[account.id] = account;
    if ((account.password ?? '').isNotEmpty) {
      await _storeCredential(account.id, account.password!);
    }
    await _sendJsonCommand('AccountUpsert', <String, dynamic>{
      'uuid': account.id,
      'account_name': account.displayName,
      'display_name': account.displayName,
      'server': account.domain,
      'sip_proxy': account.outboundProxy ?? '',
      'username': account.username,
      'auth_username': account.authUsername,
      'domain': account.domain,
      'password': account.password ?? '',
      'transport': account.transport,
      'stun_server': account.stunServer ?? '',
      'turn_server': account.turnServer ?? '',
      'tls_enabled': account.tlsEnabled,
      'srtp_enabled': account.srtpEnabled,
      'register_expires_seconds': account.registerExpiresSeconds,
      'codecs': account.codecs,
      'dtmf_mode': account.dtmfMode,
      'voicemail_number': account.voicemailNumber ?? '',
      'publish_presence': false,
    });
  }

  @override
  Future<void> removeAccount(String accountId) async {
    _accounts.remove(accountId);
    await _sendJsonCommand('AccountUnregister', <String, dynamic>{
      'uuid': accountId,
    });
    await _sendJsonCommand('AccountDeleteProfile', <String, dynamic>{
      'uuid': accountId,
    });
  }

  @override
  Future<void> registerAccount(String accountId) async {
    final account = _accounts[accountId];
    if (account == null) {
      _events.add(
        AccountRegistrationChanged(
          accountId: accountId,
          state: BridgeRegistrationState.failed,
          reason: 'Missing cached account credentials',
        ),
      );
      return;
    }

    final resolvedPassword = (account.password ?? '').isNotEmpty
        ? account.password!
        : await _retrieveCredential(accountId);
    if (resolvedPassword == null || resolvedPassword.isEmpty) {
      _events.add(
        AccountRegistrationChanged(
          accountId: accountId,
          state: BridgeRegistrationState.failed,
          reason: 'Missing cached account credentials',
        ),
      );
      return;
    }

    final idPtr = account.id.toNativeUtf8().cast<ffi.Char>();
    final userPtr = account.username.toNativeUtf8().cast<ffi.Char>();
    final passPtr = resolvedPassword.toNativeUtf8().cast<ffi.Char>();
    final domainPtr = account.domain.toNativeUtf8().cast<ffi.Char>();
    try {
      _engineRegister(idPtr, userPtr, passPtr, domainPtr);
    } finally {
      calloc.free(idPtr);
      calloc.free(userPtr);
      calloc.free(passPtr);
      calloc.free(domainPtr);
    }
  }

  @override
  Future<void> unregisterAccount(String accountId) async {
    final idPtr = accountId.toNativeUtf8().cast<ffi.Char>();
    try {
      _engineUnregister(idPtr);
    } finally {
      calloc.free(idPtr);
    }
  }

  @override
  Future<CallStartResult> startCall({
    required String accountId,
    required String destination,
  }) async {
    final idPtr = accountId.toNativeUtf8().cast<ffi.Char>();
    final dstPtr = destination.toNativeUtf8().cast<ffi.Char>();
    _pendingOutgoingCallId?.complete('pending');
    _pendingOutgoingCallId = Completer<String>();
    try {
      final result = _engineMakeCall(idPtr, dstPtr);
      if (result != 0) {
        _pendingOutgoingCallId = null;
        return const CallStartResult(callId: 'pending', accepted: false);
      }
      try {
        final callId = await _pendingOutgoingCallId!.future.timeout(
          const Duration(milliseconds: 700),
        );
        return CallStartResult(callId: callId, accepted: true);
      } on TimeoutException {
        _pendingOutgoingCallId = null;
        return const CallStartResult(callId: 'pending', accepted: true);
      }
    } finally {
      calloc.free(idPtr);
      calloc.free(dstPtr);
    }
  }

  @override
  Future<void> answerCall(String callId) async {
    _engineAnswerCall();
  }

  @override
  Future<void> rejectCall(String callId) async {
    _engineHangup();
  }

  @override
  Future<void> hangupCall(String callId) async {
    _engineHangup();
  }

  @override
  Future<void> setMute(String callId, bool muted) async {
    _engineSetMute(muted ? 1 : 0);
  }

  @override
  Future<void> setHold(String callId, bool onHold) async {
    _engineSetHold(onHold ? 1 : 0);
  }

  @override
  Future<void> sendDtmf(String callId, String digits) async {
    final digitsPtr = digits.toNativeUtf8().cast<ffi.Char>();
    try {
      _engineSendDtmf(digitsPtr);
    } finally {
      calloc.free(digitsPtr);
    }
  }

  @override
  Future<void> simulateIncomingCall({
    required String accountId,
    required String remoteUri,
    String? displayName,
  }) async {
      _events.add(
        NativeLogEvent(
          level: 'warn',
          message:
            'Incoming call simulation is disabled for the shared native adapter',
          timestamp: DateTime.now(),
        ),
      );
  }

  @override
  Future<void> blindTransfer(String callId, String destination) async {
    final nativeCallId = _parseCallId(callId);
    if (nativeCallId == null) {
      return;
    }

    final destinationPtr = destination.toNativeUtf8().cast<ffi.Char>();
    try {
      _engineTransferCall(nativeCallId, destinationPtr);
    } finally {
      calloc.free(destinationPtr);
    }
  }

  @override
  Future<AttendedTransferSession> beginAttendedTransfer(
    String callId,
    String destination,
  ) async {
    final nativeCallId = _parseCallId(callId);
    if (nativeCallId == null) {
      return AttendedTransferSession(
        originalCallId: callId,
        consultCallId: 'unsupported',
      );
    }

    final destinationPtr = destination.toNativeUtf8().cast<ffi.Char>();
    late final int consultCallId;
    try {
      consultCallId = _engineStartAttendedXfer(nativeCallId, destinationPtr);
    } finally {
      calloc.free(destinationPtr);
    }

    return AttendedTransferSession(
      originalCallId: callId,
      consultCallId: consultCallId > 0 ? '$consultCallId' : 'unsupported',
    );
  }

  @override
  Future<void> completeAttendedTransfer({
    required String originalCallId,
    required String consultCallId,
  }) async {
    final originalNativeId = _parseCallId(originalCallId);
    final consultNativeId = _parseCallId(consultCallId);
    if (originalNativeId == null || consultNativeId == null) {
      return;
    }

    _engineCompleteXfer(originalNativeId, consultNativeId);
  }

  @override
  Future<void> setAudioRoute(String route) async {
    final bridgeRoute = _audioRouteFor(route);
    final outputId = _pickOutputDeviceForRoute(bridgeRoute);
    _selectedOutputId = outputId;
    _engineSetAudioDevices(_selectedInputId, outputId);
    _events.add(AudioRouteChanged(route: bridgeRoute));
  }

  @override
  Future<String> exportDiagnostics(String directoryPath) async {
    _diagnosticsExportWaiter?.complete(null);
    _diagnosticsExportWaiter = Completer<String?>();
    await _sendJsonCommand('DiagExportBundle', <String, dynamic>{
      'directory_path': directoryPath,
      'anonymize': false,
    });
    try {
      return await _diagnosticsExportWaiter!.future.timeout(
            const Duration(milliseconds: 500),
          ) ??
          '';
    } on TimeoutException {
      _diagnosticsExportWaiter = null;
      return '';
    }
  }

  static void _eventCallback(int eventId, ffi.Pointer<ffi.Char> payload) {
    _activeInstance?._handleEvent(eventId, payload.cast<Utf8>().toDartString());
  }

  void _handleEvent(int eventId, String payload) {
    final decoded = payload.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(payload) as Map<String, dynamic>;
    final eventBody = _unwrapPayload(decoded);

    switch (eventId) {
      case 1:
        _events.add(const EngineReady());
        return;
      case 2:
        _events.add(
          AccountRegistrationChanged(
            accountId: '${eventBody['account_id'] ?? ''}',
            state: _registrationState('${eventBody['state'] ?? ''}'),
            reason: (eventBody['reason'] as String?)?.trim().isEmpty ?? true
                ? null
                : eventBody['reason'] as String?,
          ),
        );
        return;
      case 3:
        final state = _callState('${eventBody['state'] ?? ''}');
        final direction = '${eventBody['direction'] ?? ''}'.toLowerCase();
        final callId = '${eventBody['call_id'] ?? ''}';
        if (direction == 'outgoing' &&
            callId.isNotEmpty &&
            _pendingOutgoingCallId != null &&
            !_pendingOutgoingCallId!.isCompleted) {
          _pendingOutgoingCallId!.complete(callId);
          _pendingOutgoingCallId = null;
        }
        if (direction == 'incoming' && state == BridgeCallState.ringing) {
          _events.add(
            IncomingCallEvent(
              callId: callId,
              accountId: '${eventBody['account_id'] ?? ''}',
              remoteUri: '${eventBody['uri'] ?? ''}',
              displayName: eventBody['display_name'] as String?,
            ),
          );
        }
        _events.add(CallStateChanged(callId: callId, state: state));
        return;
      case 4:
        final callId = '${eventBody['call_id'] ?? ''}';
        if (callId.isEmpty) {
          return;
        }
        _events.add(
          CallMediaChanged(
            callId: callId,
            audioActive: eventBody['audio_active'] as bool? ?? true,
          ),
        );
        return;
      case 9:
        final diagnosticsPath = _diagnosticsPath(eventBody);
        _diagnosticsExportWaiter?.complete(diagnosticsPath);
        _diagnosticsExportWaiter = null;
        _events.add(
          DiagnosticsReportReady(
            success:
                eventBody['success'] as bool? ??
                ((diagnosticsPath ?? '').isNotEmpty),
            summary:
                eventBody['summary'] as String? ??
                ((diagnosticsPath ?? '').isNotEmpty
                    ? 'Native diagnostics bundle exported'
                    : 'Native diagnostics export completed without a bundle path'),
            path: diagnosticsPath,
          ),
        );
        _events.add(
          NativeLogEvent(
            level: 'info',
            message: 'Native diagnostics ready${_diagSuffix(eventBody)}',
            timestamp: DateTime.now(),
          ),
        );
        return;
      case 10:
        _events.add(
          NativeLogEvent(
            level: 'info',
            message:
                'Account security updated for ${eventBody['account_id'] ?? 'unknown'}',
            timestamp: DateTime.now(),
          ),
        );
        return;
      case 11:
        final key = '${eventBody['key'] ?? ''}';
        _credentialWaiters.remove(key)?.complete(null);
        _events.add(
          NativeLogEvent(
            level: 'debug',
            message:
                'Native credential stored for ${eventBody['key'] ?? 'unknown'}',
            timestamp: DateTime.now(),
          ),
        );
        return;
      case 12:
        final key = '${eventBody['key'] ?? ''}';
        _credentialWaiters.remove(key)?.complete(eventBody['value'] as String?);
        _events.add(
          NativeLogEvent(
            level: 'debug',
            message:
                'Native credential retrieved for ${eventBody['key'] ?? 'unknown'}',
            timestamp: DateTime.now(),
          ),
        );
        return;
      case 16:
        final rawTimestamp = eventBody['ts'];
        final timestamp = rawTimestamp is num
            ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt() * 1000)
            : DateTime.now();
        _events.add(
          NativeLogEvent(
            level: '${eventBody['level'] ?? 'Info'}'.toLowerCase(),
            message: eventBody['message'] as String? ?? payload,
            timestamp: timestamp,
          ),
        );
        return;
      case 15:
        final lines = _extractLogLines(eventBody);
        _events.add(
          LogBufferReceived(
            lines: lines,
            summary: 'Native log buffer returned ${lines.length} lines',
          ),
        );
        return;
      case 17:
      case 18:
      case 19:
      case 20:
        _events.add(
          TransferEvent(
            kind: _transferKindFor(eventId),
            callId:
                '${eventBody['call_id'] ?? eventBody['original_call_id'] ?? ''}',
            consultCallId:
                '${eventBody['consult_call_id'] ?? eventBody['other_call_id'] ?? ''}'
                    .trim()
                    .isEmpty
                ? null
                : '${eventBody['consult_call_id'] ?? eventBody['other_call_id'] ?? ''}',
            destination:
                '${eventBody['destination'] ?? eventBody['target_uri'] ?? ''}'
                    .trim()
                    .isEmpty
                ? null
                : '${eventBody['destination'] ?? eventBody['target_uri'] ?? ''}',
            message:
                '${decoded['type'] ?? 'transfer'}: ${eventBody['message'] ?? eventBody['status'] ?? 'native event'}',
          ),
        );
        _events.add(
          NativeLogEvent(
            level: 'info',
            message: 'Native transfer event ${decoded['type'] ?? eventId}: $eventBody',
            timestamp: DateTime.now(),
          ),
        );
        return;
      case 5:
        _updateAudioDevices(eventBody);
        _events.add(
          AudioDevicesChanged(
            devices: _audioDevices
                .map(
                  (device) => BridgeAudioDevice(
                    id: device.id,
                    name: device.name,
                    kind: device.kind,
                  ),
                )
                .toList(growable: false),
            selectedInputId: _selectedInputId,
            selectedOutputId: _selectedOutputId,
          ),
        );
        _emitCurrentAudioRoute();
        return;
      case 6:
        _updateSelectedAudioDevices(eventBody);
        _events.add(
          AudioDevicesChanged(
            devices: _audioDevices
                .map(
                  (device) => BridgeAudioDevice(
                    id: device.id,
                    name: device.name,
                    kind: device.kind,
                  ),
                )
                .toList(growable: false),
            selectedInputId: _selectedInputId,
            selectedOutputId: _selectedOutputId,
          ),
        );
        final route = _routeFromAudioEvent(eventBody);
        if (route != null) {
          _events.add(AudioRouteChanged(route: route));
        }
        return;
      case 45:
      case 46:
      case 47:
      case 48:
        _events.add(
          RecordingEvent(
            kind: _recordingKindFor(eventId),
            callId: _stringOrNull(eventBody['call_id']),
            filePath: _stringOrNull(
              eventBody['absolute_file_path'] ??
                  eventBody['file_path'] ??
                  eventBody['path'],
            ),
            message: _stringOrNull(eventBody['message'] ?? eventBody['reason']),
          ),
        );
        return;
      default:
        return;
    }
  }

  Map<String, dynamic> _unwrapPayload(Map<String, dynamic> decoded) {
    final payload = decoded['payload'];
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    return decoded;
  }

  String _diagSuffix(Map<String, dynamic> payload) {
    final bundlePath = _diagnosticsPath(payload);
    if (bundlePath == null || bundlePath.isEmpty) {
      return '';
    }
    return ' at $bundlePath';
  }

  String? _diagnosticsPath(Map<String, dynamic> payload) {
    final bundlePath =
        payload['absolute_file_path'] ??
        payload['bundle_path'] ??
        payload['path'];
    final path = bundlePath?.toString().trim();
    return (path == null || path.isEmpty) ? null : path;
  }

  List<String> _extractLogLines(Map<String, dynamic> payload) {
    final rawLines = payload['lines'];
    if (rawLines is List) {
      return rawLines.map((line) => '$line').toList(growable: false);
    }
    final rawBuffer =
        payload['buffer'] ?? payload['log_buffer'] ?? payload['logs'];
    if (rawBuffer is String) {
      return rawBuffer
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trimRight())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  String? _stringOrNull(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  int? _parseCallId(String callId) => int.tryParse(callId);

  BridgeAudioRoute _audioRouteFor(String route) {
    switch (route.toLowerCase()) {
      case 'speaker':
        return BridgeAudioRoute.speaker;
      case 'bluetooth':
        return BridgeAudioRoute.bluetooth;
      case 'headset':
        return BridgeAudioRoute.headset;
      default:
        return BridgeAudioRoute.earpiece;
    }
  }

  BridgeAudioRoute? _routeFromAudioEvent(Map<String, dynamic> payload) {
    final selectedOutput = payload['selected_output'] ?? payload['output_id'];
    if (selectedOutput == null) {
      return null;
    }
    final outputId = selectedOutput is num
        ? selectedOutput.toInt()
        : int.tryParse('$selectedOutput');
    if (outputId == null) {
      return null;
    }
    _selectedOutputId = outputId;
    final output = _audioDevices
        .where((device) => device.isOutput)
        .firstWhere(
          (device) => device.id == outputId,
          orElse: () =>
              const _AudioDeviceEntry(id: 1, name: '', kind: 'Output'),
        );
    return _routeForDeviceName(output.name);
  }

  Future<void> _sendJsonCommand(
    String type,
    Map<String, dynamic> payload,
  ) async {
    final typePtr = type.toNativeUtf8().cast<ffi.Char>();
    final payloadPtr = jsonEncode(payload).toNativeUtf8().cast<ffi.Char>();
    try {
      _engineSendCommand(typePtr, payloadPtr);
    } finally {
      calloc.free(typePtr);
      calloc.free(payloadPtr);
    }
  }

  Future<void> _storeCredential(String accountId, String value) {
    return _sendJsonCommand('CredStore', <String, dynamic>{
      'key': _credentialKey(accountId),
      'value': value,
    });
  }

  Future<String?> _retrieveCredential(String accountId) async {
    final key = _credentialKey(accountId);
    final completer = Completer<String?>();
    _credentialWaiters[key]?.complete(null);
    _credentialWaiters[key] = completer;
    await _sendJsonCommand('CredRetrieve', <String, dynamic>{'key': key});
    try {
      return await completer.future.timeout(const Duration(milliseconds: 500));
    } on TimeoutException {
      _credentialWaiters.remove(key);
      return null;
    }
  }

  String _credentialKey(String accountId) => 'sip_password:$accountId';

  void _updateAudioDevices(Map<String, dynamic> payload) {
    final devices = (payload['devices'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => _AudioDeviceEntry(
            id: (item['id'] as num?)?.toInt() ?? 0,
            name: item['name'] as String? ?? '',
            kind: item['kind'] as String? ?? '',
          ),
        )
        .toList();
    _audioDevices = devices;
    _updateSelectedAudioDevices(payload);
  }

  void _updateSelectedAudioDevices(Map<String, dynamic> payload) {
    final selectedInput = payload['selected_input'] ?? payload['input_id'];
    final selectedOutput = payload['selected_output'] ?? payload['output_id'];
    if (selectedInput is num) {
      _selectedInputId = selectedInput.toInt();
    }
    if (selectedOutput is num) {
      _selectedOutputId = selectedOutput.toInt();
    }
  }

  void _emitCurrentAudioRoute() {
    final route = _routeFromAudioEvent(<String, dynamic>{
      'output_id': _selectedOutputId,
    });
    if (route != null) {
      _events.add(AudioRouteChanged(route: route));
    }
  }

  int _pickOutputDeviceForRoute(BridgeAudioRoute route) {
    final outputs = _audioDevices.where((device) => device.isOutput).toList();
    final matched = outputs.where((device) {
      final mapped = _routeForDeviceName(device.name);
      return mapped == route;
    }).toList();
    if (matched.isNotEmpty) {
      return matched.first.id;
    }
    return outputs.isNotEmpty ? outputs.first.id : _selectedOutputId;
  }

  BridgeAudioRoute _routeForDeviceName(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('bluetooth') ||
        normalized.contains('airpods') ||
        normalized.contains('hands-free')) {
      return BridgeAudioRoute.bluetooth;
    }
    if (normalized.contains('headset') ||
        normalized.contains('headphone') ||
        normalized.contains('earbud')) {
      return BridgeAudioRoute.headset;
    }
    if (normalized.contains('speaker')) {
      return BridgeAudioRoute.speaker;
    }
    return BridgeAudioRoute.earpiece;
  }

  BridgeRegistrationState _registrationState(String value) {
    switch (value.toLowerCase()) {
      case 'registering':
        return BridgeRegistrationState.registering;
      case 'registered':
        return BridgeRegistrationState.registered;
      case 'failed':
        return BridgeRegistrationState.failed;
      default:
        return BridgeRegistrationState.unregistered;
    }
  }

  BridgeCallState _callState(String value) {
    switch (value.toLowerCase()) {
      case 'ringing':
        return BridgeCallState.ringing;
      case 'incall':
      case 'active':
        return BridgeCallState.active;
      case 'onhold':
      case 'held':
        return BridgeCallState.held;
      case 'ended':
        return BridgeCallState.ended;
      case 'connecting':
      case 'calling':
        return BridgeCallState.connecting;
      default:
        return BridgeCallState.idle;
    }
  }

  TransferEventKind _transferKindFor(int eventId) {
    switch (eventId) {
      case 17:
        return TransferEventKind.blindRequested;
      case 18:
        return TransferEventKind.attendedStarted;
      case 19:
        return TransferEventKind.attendedCompleted;
      case 20:
        return TransferEventKind.status;
      default:
        return TransferEventKind.status;
    }
  }

  RecordingEventKind _recordingKindFor(int eventId) {
    switch (eventId) {
      case 45:
        return RecordingEventKind.started;
      case 46:
        return RecordingEventKind.stopped;
      case 47:
        return RecordingEventKind.saved;
      case 48:
        return RecordingEventKind.error;
      default:
        return RecordingEventKind.error;
    }
  }
}

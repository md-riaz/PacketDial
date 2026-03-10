import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import '../ffi/engine.dart';
import '../models/account.dart';
import '../models/audio_device.dart';
import '../models/call.dart';
import '../models/call_history.dart';
import '../models/log_entry.dart';
import '../models/sip_message.dart';
import '../models/media_stats.dart';
import '../models/call_history_schema.dart';
import 'account_service.dart';
import 'audio_service.dart';
import 'call_event_service.dart';
import 'integration_service.dart';
import 'recording_service.dart';

/// Maximum number of structured log entries retained in memory.
const _kLogBufferMax = 500;
const _kSipMessageMax = 200;
const _kEventLogMax = 500;
const _kSipRawPreviewMax = 240;

/// Bridges the Dart UI to the Rust core via structured C ABI and callbacks.
///
/// * Commands are sent via structured C functions (register, makeCall, etc.).
/// * Events are received via native callbacks and broadcast on [events].
/// * Higher-level state ([accounts], [activeCall], [callHistory], etc.) is
///   maintained here so individual screens can read it without each managing
///   their own subscriptions.
class EngineChannel {
  EngineChannel._();
  static final EngineChannel instance = EngineChannel._();

  VoipEngine? _engine;
  AccountService? _accountService;
  ffi.NativeCallable<ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>?
      _nativeCallable;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  /// Broadcast stream of raw event maps from the engine.
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  /// Compatibility getter for engine_provider.dart
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  // --- Public state -----------------------------------------------------------

  bool engineReady = false;

  /// All known accounts, keyed by id.
  final Map<String, Account> accounts = {};

  /// The currently active call, or null if no call is in progress.
  ActiveCall? activeCall;

  /// Media stats for the active call, keyed by call_id.
  final Map<int, MediaStats> mediaStats = {};

  /// Completed call history (most recent last).
  final List<CallHistoryEntry> callHistory = [];

  /// Known audio devices from the last AudioDeviceList event.
  final List<AudioDevice> audioDevices = [];
  int selectedInputId = 0;
  int selectedOutputId = 1;

  /// Raw event JSON strings for the Diagnostics screen (event log tab).
  final List<String> eventLog = [];

  /// Structured log entries emitted by the engine (log tab).
  final List<LogEntry> logBuffer = [];

  /// Captured SIP messages (REGISTER, INVITE, responses, etc.).
  final List<SipMessage> sipMessages = [];

  // --- Lifecycle --------------------------------------------------------------

  /// Attach the channel to a loaded [VoipEngine] and register callback.
  void attach(VoipEngine engine, AccountService accountService) {
    // CRITICAL: Ensure any old callback is nulled in the native engine first
    // to prevent crashes if native worker threads try to call a deleted callback pointer.
    try {
      engine.setEventCallback(ffi.nullptr);
    } catch (_) {}

    _engine = engine;
    _accountService = accountService;

    // Use NativeCallable.listener for thread-safe callbacks from PJSIP worker threads.
    _nativeCallable = ffi.NativeCallable<
        ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>.listener(
      _eventCallbackStatic,
    );

    // Register the native function pointer with the engine.
    engine.setEventCallback(_nativeCallable!.nativeFunction);

    // Request audio device list on startup
    engine.listAudioDevices();

    // Re-request audio devices after a short delay to catch late-initialized devices
    // This helps with Windows audio subsystem initialization timing issues
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_engine != null) {
        debugPrint('[EngineChannel] Re-enumerating audio devices after delay');
        engine.listAudioDevices();
      }
    });

    // Initialize audio feedback service
    AudioService.instance.init();
  }

  /// Clears in-memory state without disposing the engine.
  void reset() {
    accounts.clear();
    mediaStats.clear();
    eventLog.clear();
    logBuffer.clear();
    sipMessages.clear();
    activeCall = null;
    engineReady = false;
  }

  void dispose() {
    // Clear the callback and close the NativeCallable
    _engine?.setEventCallback(ffi.nullptr);
    _nativeCallable?.close();
    _engine?.shutdown();
    _eventController.close();
  }

  // Native callback handler (must be static and top-level compatible)
  static void _eventCallbackStatic(
      int eventId, ffi.Pointer<ffi.Int8> jsonDataPtr) {
    instance._handleNativeEvent(eventId, jsonDataPtr);
  }

  // Instance method to handle events from native callback
  void _handleNativeEvent(int eventId, ffi.Pointer<ffi.Int8> jsonDataPtr) {
    try {
      // Read JSON payload from C string
      final jsonData = _ptrToString(jsonDataPtr);
      final trimmed = jsonData.trim();
      if (trimmed.isEmpty) {
        debugPrint(
            '[EngineChannel] Ignored empty payload for event id=$eventId');
        return;
      }
      if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
        debugPrint(
            '[EngineChannel] Ignored non-JSON payload for event id=$eventId: ${trimmed.length > 80 ? "${trimmed.substring(0, 80)}..." : trimmed}');
        return;
      }

      // Parse JSON payload
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        debugPrint(
            '[EngineChannel] Ignored non-object payload for event id=$eventId');
        return;
      }
      final payload = decoded;

      // Map event ID to event type string
      final eventType = _eventIdToType(eventId);

      // Always hop off the FFI callback stack before touching app/services code.
      // Incoming call events originate from native worker threads; processing
      // them synchronously here can trigger plugin calls from the wrong context.
      Future<void>(() {
        _dispatchEvent(eventType, payload);
      });
    } catch (e) {
      debugPrint(
          '[EngineChannel] Dropped event (id=$eventId) due to parse error: $e');
    }
  }

  void _dispatchEvent(String eventType, Map<String, dynamic> payload) {
    final event = <String, dynamic>{'type': eventType, 'payload': payload};
    final phase = SchedulerBinding.instance.schedulerPhase;
    final inBuildPhase = phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;

    if (inBuildPhase) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _processEvent(eventType, payload, event);
      });
      return;
    }

    _processEvent(eventType, payload, event);
  }

  void _processEvent(String eventType, Map<String, dynamic> payload,
      Map<String, dynamic> event) {
    // Store in event log
    _appendEventLog(eventType, payload);

    // Handle the event
    _handleEvent(event);

    // Broadcast to listeners
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _appendEventLog(String eventType, Map<String, dynamic> payload) {
    Map<String, dynamic> payloadForLog = payload;
    if (eventType == 'SipMessageCaptured') {
      final raw = payload['raw'] as String? ?? '';
      if (raw.isNotEmpty) {
        final preview = raw.length > _kSipRawPreviewMax
            ? '${raw.substring(0, _kSipRawPreviewMax)}...'
            : raw;
        payloadForLog = Map<String, dynamic>.from(payload)
          ..['raw'] = preview
          ..['raw_len'] = raw.length;
      }
    }
    eventLog.add(jsonEncode({'type': eventType, 'payload': payloadForLog}));
    if (eventLog.length > _kEventLogMax) {
      eventLog.removeAt(0);
    }
  }

  /// Convert event ID to event type string
  String _eventIdToType(int eventId) {
    switch (eventId) {
      case EngineEventId.engineReady:
        return 'EngineReady';
      case EngineEventId.registrationStateChanged:
        return 'RegistrationStateChanged';
      case EngineEventId.callStateChanged:
        return 'CallStateChanged';
      case EngineEventId.mediaStatsUpdated:
        return 'MediaStatsUpdated';
      case EngineEventId.audioDeviceList:
        return 'AudioDeviceList';
      case EngineEventId.audioDevicesSet:
        return 'AudioDevicesSet';
      case EngineEventId.callHistoryResult:
        return 'CallHistoryResult';
      case EngineEventId.sipMessageCaptured:
        return 'SipMessageCaptured';
      case EngineEventId.diagBundleReady:
        return 'DiagBundleReady';
      case EngineEventId.accountSecurityUpdated:
        return 'AccountSecurityUpdated';
      case EngineEventId.credStored:
        return 'CredStored';
      case EngineEventId.credRetrieved:
        return 'CredRetrieved';
      case EngineEventId.enginePong:
        return 'EnginePong';
      case EngineEventId.logLevelSet:
        return 'LogLevelSet';
      case EngineEventId.logBufferResult:
        return 'LogBufferResult';
      case EngineEventId.engineLog:
        return 'EngineLog';
      case EngineEventId.callTransferInitiated:
        return 'CallTransferInitiated';
      case EngineEventId.callTransferStatus:
        return 'CallTransferStatus';
      case EngineEventId.callTransferCompleted:
        return 'CallTransferCompleted';
      case EngineEventId.conferenceMerged:
        return 'ConferenceMerged';
      default:
        return 'Unknown';
    }
  }

  /// Helper to read C string
  String _ptrToString(ffi.Pointer<ffi.Int8> ptr) {
    if (ptr.address == 0) return '';
    return ptr.cast<Utf8>().toDartString();
  }

  // --- Command helpers (now using structured C ABI) ---------------------------

  VoipEngine get engine => _engine!;

  /// Set the active log level filter in the engine.
  void setLogLevel(String level) {
    _engine?.setLogLevel(level);
  }

  /// Request all buffered log entries from the engine.
  void getLogBuffer() {
    _engine?.getLogBuffer();
  }

  /// Send DTMF digits on the active call.
  void sendDtmf(String digits) {
    _engine?.sendDtmf(digits);
  }

  /// Play DTMF digits locally.
  void playDtmf(String digits) {
    _engine?.playDtmf(digits);
  }

  /// Delete an account profile and remove it from the engine.
  void deleteAccount(String uuid) {
    _engine?.deleteAccount(uuid);
  }

  /// Toggle mute on the active call.
  void setMute(bool muted) {
    _engine?.setMute(muted);
  }

  /// Toggle hold on the active call.
  void setHold(bool onHold) {
    _engine?.setHold(onHold);
  }

  /// Initiate blind transfer of the active call to a destination URI.
  /// Returns error code (0 = success).
  int transferCall(int callId, String destUri) {
    return _engine?.transferCall(callId, destUri) ?? -1;
  }

  /// Start attended (consultative) transfer.
  /// Puts current call on hold and initiates a consultation call.
  /// Returns consultation call ID on success, or negative error code.
  int startAttendedXfer(int callId, String destUri) {
    return _engine?.startAttendedXfer(callId, destUri) ?? -1;
  }

  /// Complete an attended transfer.
  /// Returns error code (0 = success).
  int completeXfer(int callAId, int callBId) {
    return _engine?.completeXfer(callAId, callBId) ?? -1;
  }

  /// Merge two calls into a 3-way conference.
  /// Returns error code (0 = success).
  int mergeConference(int callAId, int callBId) {
    return _engine?.mergeConference(callAId, callBId) ?? -1;
  }

  Future<void> _stopRecordingDeferred() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!RecordingService.instance.isRecording) return;
    try {
      await RecordingService.instance.stopRecording();
    } catch (e) {
      debugPrint('[EngineChannel] Deferred recording stop failed: $e');
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final payload =
        (event['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    // Always print all events for debugging (truncated for performance)
    if (type == 'SipMessageCaptured') {
      final direction = payload['direction'] as String? ?? '?';
      final callId = payload['call_id'];
      final raw = payload['raw'] as String? ?? '';
      final preview = raw.isEmpty
          ? ''
          : (raw.length > 120 ? '${raw.substring(0, 120)}...' : raw);
      debugPrint(
          '[EngineChannel] Event: SipMessageCaptured, call_id=$callId, direction=$direction, raw_len=${raw.length}, preview="$preview"');
    } else if (type == 'EngineLog') {
      final msg = payload['message'] as String? ?? '';
      final preview = msg.length > 100 ? '${msg.substring(0, 100)}...' : msg;
      debugPrint(
          '[EngineChannel] Event: $type, Payload: {level: ${payload['level']}, message: $preview}');
    } else {
      debugPrint('[EngineChannel] Event: $type, Payload: $payload');
    }

    switch (type) {
      case 'EngineReady':
        engineReady = true;

      case 'RegistrationStateChanged':
        final id = payload['account_id'] as String? ?? '';
        final accountName = payload['account_name'] as String? ?? 'SIP Account';
        final displayName = payload['display_name'] as String? ?? '';
        final state =
            RegistrationState.fromString(payload['state'] as String? ?? '');
        final reason = payload['reason'] as String? ?? '';

        if (!accounts.containsKey(id)) {
          // If account is not in our live map (e.g. initial registration from db),
          // create a placeholder so the UI can show the status.
          accounts[id] = Account(
            uuid: id,
            accountName: accountName,
            displayName: displayName,
            server: payload['server'] as String? ?? '',
            username: payload['username'] as String? ?? '',
            password: '',
            registrationState: state,
            failureReason: reason,
          );
        } else {
          final existing = accounts[id]!;
          final newServer = payload['server'] as String? ?? '';
          final newUsername = payload['username'] as String? ?? '';

          accounts[id] = existing.copyWith(
            accountName: accountName,
            displayName: displayName,
            server: newServer.isNotEmpty ? newServer : existing.server,
            username: newUsername.isNotEmpty ? newUsername : existing.username,
            registrationState: state,
            failureReason: reason,
          );
        }

      case 'CallStateChanged':
        final callId = (payload['call_id'] as num?)?.toInt() ?? 0;
        final state = CallState.fromString(payload['state'] as String? ?? '');
        final eventCall = ActiveCall(
          callId: callId,
          accountId: payload['account_id'] as String? ?? '',
          uri: payload['uri'] as String? ?? '',
          direction:
              CallDirection.fromString(payload['direction'] as String? ?? ''),
          state: state,
          muted: payload['muted'] as bool? ?? false,
          onHold: payload['on_hold'] as bool? ?? false,
          startedAt: activeCall?.startedAt ??
              ((state == CallState.inCall) ? DateTime.now() : null),
          accumulatedSeconds: payload['accumulated_active_secs'] as int? ?? 0,
          lastResumedAt: payload['last_resumed_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  (payload['last_resumed_at'] as int) * 1000)
              : null,
        );
        activeCall = eventCall;

        debugPrint(
            '[EngineChannel] Emitting CallEvent for call $callId, state $state');

        // Emit call event to all listeners (thread-safe, no platform calls)
        CallEventService.instance.addEvent(CallEvent(
          callId: callId,
          accountId: payload['account_id'] as String? ?? '',
          state: state.toString(),
          direction: payload['direction'] as String? ?? '',
          uri: payload['uri'] as String? ?? '',
          accountName: payload['account_name'] as String?,
          accountUser: payload['account_user'] as String?,
          extid: payload['extid'] as String?,
          customerData: payload['customer_data'] as Map<String, dynamic>?,
          timestamp: DateTime.now(),
        ));

        if (state == CallState.ended) {
          final endedRecordingPath = (payload['recording_path'] as String?) ??
              RecordingService.instance.currentRecordingPath;

          // Stop recording if active
          if (RecordingService.instance.isRecording) {
            unawaited(_stopRecordingDeferred());
          }

          if (activeCall?.callId == callId) {
            // Save to JSON via AccountService
            if (_accountService != null) {
              final sipCode = (payload['sip_code'] as num?)?.toInt();
              final sipReason = payload['sip_reason'] as String?;

              // Map SIP code to professional Result (Spec 2.2)
              String result = 'Ended';
              if (activeCall!.direction == CallDirection.incoming) {
                if (sipCode == 487) {
                  result = 'Missed';
                } else if (sipCode == 603 || sipCode == 486) {
                  result = 'Rejected';
                } else if (activeCall!.state == CallState.inCall) {
                  result = 'Answered';
                } else {
                  result = 'Missed';
                }
              } else {
                if (activeCall!.state == CallState.inCall) {
                  result = 'Answered';
                } else if (sipCode == 486) {
                  result = 'Busy';
                } else if (sipCode == 487) {
                  result = 'Cancelled';
                } else if (sipCode != null && sipCode >= 400) {
                  result = 'Failed';
                } else {
                  result = 'Disconnected';
                }
              }

              final entry = CallHistorySchema(
                id: '', // Will be set in AccountService
                accountId: activeCall!.accountId,
                uri: activeCall!.uri,
                direction: activeCall!.direction.name,
                timestamp: DateTime.now(),
                durationSeconds: activeCall!.startedAt != null
                    ? DateTime.now()
                        .difference(activeCall!.startedAt!)
                        .inSeconds
                    : 0,
                sipCode: sipCode,
                sipReason: sipReason,
                result: result,
              );

              _accountService!.saveCallHistory(entry);
            }

            // Trigger CRM End Hook and Recording Upload
            if (activeCall != null) {
              IntegrationService.instance.onCallEnd(
                activeCall!,
                recordingPath: endedRecordingPath,
              );
            }

            activeCall = null;
          }
          mediaStats.remove(callId);
          // Refresh call history
          _engine?.queryCallHistory();
        }

      case 'MediaStatsUpdated':
        final stats = MediaStats.fromMap(payload);
        mediaStats[stats.callId] = stats;

      case 'AudioDeviceList':
        audioDevices.clear();
        final list = payload['devices'] as List<dynamic>? ?? [];
        for (final d in list) {
          audioDevices.add(AudioDevice.fromMap(d as Map<String, dynamic>));
        }
        selectedInputId = (payload['selected_input'] as num?)?.toInt() ?? 0;
        selectedOutputId = (payload['selected_output'] as num?)?.toInt() ?? 1;

      case 'AudioDevicesSet':
        selectedInputId = (payload['input_id'] as num?)?.toInt() ?? 0;
        selectedOutputId = (payload['output_id'] as num?)?.toInt() ?? 1;

      case 'CallHistoryResult':
        callHistory.clear();
        final entries = payload['entries'] as List<dynamic>? ?? [];
        for (final e in entries) {
          callHistory.add(CallHistoryEntry.fromMap(e as Map<String, dynamic>));
        }

      case 'EngineLog':
        final entry = LogEntry.fromMap(payload);
        logBuffer.add(entry);
        if (logBuffer.length > _kLogBufferMax) {
          logBuffer.removeAt(0);
        }

      case 'LogBufferResult':
        logBuffer.clear();
        final entries = payload['entries'] as List<dynamic>? ?? [];
        for (final e in entries) {
          logBuffer.add(LogEntry.fromMap(e as Map<String, dynamic>));
        }

      case 'SipMessageCaptured':
        final msg = SipMessage.fromMap(payload);
        sipMessages.add(msg);
        if (sipMessages.length > _kSipMessageMax) {
          sipMessages.removeAt(0);
        }

      case 'CallTransferInitiated':
        // Transfer initiated - UI already shows feedback via SnackBar
        debugPrint('[EngineChannel] Call transfer initiated: $payload');

      case 'CallTransferStatus':
        // Handle transfer status updates from PJSIP
        final callId = (payload['call_id'] as num?)?.toInt() ?? 0;
        final statusCode = (payload['status_code'] as num?)?.toInt() ?? 0;
        final statusText = payload['status_text'] as String? ?? '';
        final isFinal = payload['final'] as bool? ?? false;
        debugPrint(
            '[EngineChannel] Transfer status: call=$callId, code=$statusCode, text=$statusText, final=$isFinal');
        if (isFinal && statusCode == 200) {
          // Transfer successful - the call will be ended automatically
          debugPrint('[EngineChannel] Transfer successful, call will be ended');
        }

      case 'CallTransferCompleted':
        // Attended transfer completed successfully
        debugPrint('[EngineChannel] Call transfer completed: $payload');

      case 'ConferenceMerged':
        // 3-way conference merged successfully
        final callAId = (payload['call_a_id'] as num?)?.toInt() ?? 0;
        final callBId = (payload['call_b_id'] as num?)?.toInt() ?? 0;
        debugPrint(
            '[EngineChannel] Conference merged: call A=$callAId, call B=$callBId');

      case 'RecordingStarted':
        // Recording started
        final filePath = payload['file_path'] as String?;
        debugPrint('[EngineChannel] Recording started: $filePath');

      case 'RecordingStopped':
        // Recording stopped
        debugPrint('[EngineChannel] Recording stopped');
        // Reset recording service state
        RecordingService.instance.reset();
    }
  }
}

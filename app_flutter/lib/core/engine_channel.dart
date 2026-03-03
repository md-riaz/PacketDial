import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;

import '../ffi/engine.dart';
import '../models/account.dart';
import '../models/audio_device.dart';
import '../models/call.dart';
import '../models/call_history.dart';
import '../models/log_entry.dart';
import '../models/media_stats.dart';

/// Maximum number of structured log entries retained in memory.
const _kLogBufferMax = 500;

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
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>>? _callbackPtr;

  final _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Broadcast stream of raw event maps from the engine.
  Stream<Map<String, dynamic>> get events => _eventController.stream;

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

  // --- Lifecycle --------------------------------------------------------------

  /// Attach the channel to a loaded [VoipEngine] and register callback.
  void attach(VoipEngine engine) {
    _engine = engine;

    // Create a Dart callback that will be called from native code
    _callbackPtr = ffi.Pointer.fromFunction<ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>(
      _eventCallbackStatic,
    );

    // Register the callback with the engine
    engine.setEventCallback(_callbackPtr!);

    // Request audio device list on startup
    engine.listAudioDevices();
  }

  void dispose() {
    // Clear the callback
    _engine?.setEventCallback(ffi.nullptr);
    _engine?.shutdown();
    _eventController.close();
  }

  // Native callback handler (must be static and top-level compatible)
  static void _eventCallbackStatic(int eventId, ffi.Pointer<ffi.Int8> jsonDataPtr) {
    instance._handleNativeEvent(eventId, jsonDataPtr);
  }

  // Instance method to handle events from native callback
  void _handleNativeEvent(int eventId, ffi.Pointer<ffi.Int8> jsonDataPtr) {
    try {
      // Read JSON payload from C string
      final jsonData = _ptrToString(jsonDataPtr);

      // Parse JSON payload
      final payload = jsonDecode(jsonData) as Map<String, dynamic>;

      // Map event ID to event type string
      final eventType = _eventIdToType(eventId);

      // Create event map
      final event = {
        'type': eventType,
        'payload': payload,
      };

      // Store in event log
      eventLog.add(jsonEncode(event));

      // Handle the event
      _handleEvent(event);

      // Broadcast to listeners
      if (!_eventController.isClosed) {
        _eventController.add(event);
      }
    } catch (e) {
      // Ignore parsing errors
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
      default:
        return 'Unknown';
    }
  }

  /// Helper to read C string
  String _ptrToString(ffi.Pointer<ffi.Int8> ptr) {
    final bytes = <int>[];
    int i = 0;
    while (true) {
      final v = (ptr + i).value;
      if (v == 0) break;
      bytes.add(v);
      i++;
    }
    return String.fromCharCodes(bytes);
  }

  // --- Command helpers (now using structured C ABI) ---------------------------

  VoipEngine get engine => _engine!;

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final payload =
        (event['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    switch (type) {
      case 'EngineReady':
        engineReady = true;

      case 'RegistrationStateChanged':
        final id = payload['account_id'] as String? ?? '';
        final state = RegistrationState.fromString(
            payload['state'] as String? ?? '');
        final reason = payload['reason'] as String? ?? '';
        if (accounts.containsKey(id)) {
          accounts[id] = accounts[id]!
              .copyWith(registrationState: state, failureReason: reason);
        }

      case 'CallStateChanged':
        final callId = (payload['call_id'] as num?)?.toInt() ?? 0;
        final state =
            CallState.fromString(payload['state'] as String? ?? '');
        if (state == CallState.ended) {
          if (activeCall?.callId == callId) activeCall = null;
          mediaStats.remove(callId);
          // Refresh call history
          _engine?.queryCallHistory();
        } else {
          activeCall = ActiveCall(
            callId: callId,
            accountId: payload['account_id'] as String? ?? '',
            uri: payload['uri'] as String? ?? '',
            direction: CallDirection.fromString(
                payload['direction'] as String? ?? ''),
            state: state,
            muted: payload['muted'] as bool? ?? false,
            onHold: payload['on_hold'] as bool? ?? false,
          );
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
    }
  }
}

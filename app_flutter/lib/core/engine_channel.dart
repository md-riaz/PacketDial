import 'dart:async';
import 'dart:convert';

import '../ffi/engine.dart';
import '../models/account.dart';
import '../models/call.dart';

/// Bridges the Dart UI to the Rust core via the command/event channel.
///
/// * Commands are sent synchronously via [sendCommand].
/// * Events are polled every 50 ms and broadcast on [events].
/// * Higher-level state ([accounts], [activeCall]) is maintained here so
///   individual screens can read it without each managing their own subscriptions.
class EngineChannel {
  EngineChannel._();
  static final EngineChannel instance = EngineChannel._();

  VoipEngine? _engine;
  Timer? _pollTimer;

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

  /// Raw event JSON strings for the Diagnostics screen.
  final List<String> eventLog = [];

  // --- Lifecycle --------------------------------------------------------------

  /// Attach the channel to a loaded [VoipEngine] and start polling.
  void attach(VoipEngine engine) {
    _engine = engine;
    _pollTimer =
        Timer.periodic(const Duration(milliseconds: 50), (_) => _poll());
  }

  void dispose() {
    _pollTimer?.cancel();
    _engine?.shutdown();
    _eventController.close();
  }

  // --- Command helpers --------------------------------------------------------

  /// Send a typed command with [payload] to the Rust core.
  /// Returns 0 on success.
  int sendCommand(String type, [Map<String, dynamic>? payload]) {
    final json = jsonEncode({'type': type, 'payload': payload ?? {}});
    return _engine?.sendCommand(json) ?? -1;
  }

  // --- Private ----------------------------------------------------------------

  void _poll() {
    final json = _engine?.pollEvent();
    if (json == null) return;
    eventLog.add(json);
    try {
      final event = jsonDecode(json) as Map<String, dynamic>;
      _handleEvent(event);
      if (!_eventController.isClosed) {
        _eventController.add(event);
      }
    } catch (_) {}
  }

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
    }
  }
}

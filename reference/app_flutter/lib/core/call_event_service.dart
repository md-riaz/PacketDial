import 'dart:async';

import 'package:flutter/foundation.dart';

import 'flutter_event_bus.dart';

/// Represents a call state change event from the engine.
class CallEvent {
  final int callId;
  final String accountId;
  final String state;
  final String direction;
  final String uri;
  final String? accountName;
  final String? accountUser;
  final String? extid;
  final Map<String, dynamic>? customerData;
  final DateTime timestamp;

  CallEvent({
    required this.callId,
    required this.accountId,
    required this.state,
    required this.direction,
    required this.uri,
    this.accountName,
    this.accountUser,
    this.extid,
    this.customerData,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'CallEvent(callId=$callId, accountId=$accountId, state=$state, '
        'direction=$direction, uri=$uri)';
  }
}

/// Service that broadcasts call state events to all listeners.
///
/// This service acts as an event bus, decoupling the engine's worker thread
/// callbacks from UI-layer consumers (audio, screen pop, notifications, etc.).
///
/// ## Thread Safety
/// All events are delivered via [FlutterEventBus], which ensures they are
/// received on Flutter's platform thread, making it safe to call platform
/// channels (just_audio, Riverpod, UI updates) from event handlers.
///
/// ## Architecture:
/// ```
/// Native Engine (worker thread)
///       ↓
/// EngineChannel (MethodChannel callback)
///       ↓
/// CallEventService.addEvent() ← Thread boundary (via FlutterEventBus)
///       ↓
/// FlutterEventBus (platform thread)
///       ↓
/// Stream Broadcast (platform thread)
///       ↓
/// ┌─────────────────────────────────┐
/// │ AudioService    │ ScreenPop     │
/// │ IncomingCall    │ Recording     │
/// └─────────────────────────────────┘
/// ```
class CallEventService {
  CallEventService._() {
    debugPrint('[CallEventService] Instance created');
  }

  static final CallEventService instance = CallEventService._();

  /// Stream of all call events. Safe to listen from any isolate.
  /// All events are guaranteed to be delivered on the platform thread.
  Stream<CallEvent> get eventStream {
    debugPrint('[CallEventService] eventStream accessed');
    return FlutterEventBus.instance.on<CallEvent>();
  }

  /// Add a call event to the broadcast stream.
  ///
  /// This method is **thread-safe** and can be called from worker threads.
  /// Events are automatically scheduled on the platform thread.
  void addEvent(CallEvent event) {
    debugPrint('[CallEventService] Adding event: $event');
    FlutterEventBus.instance.postTracked(event, context: 'CallEvent: ${event.state}');
  }

  void dispose() {
    debugPrint('[CallEventService] Disposing');
    // FlutterEventBus manages the actual stream lifecycle
  }
}

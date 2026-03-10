import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A thread-safe event bus that ensures all events are delivered on Flutter's
/// platform (UI) thread.
///
/// ## Problem Solved
/// Native engine callbacks arrive on worker threads, but Flutter platform
/// channels (like just_audio, riverpod state updates, UI changes) must be
/// called from the platform thread.
///
/// ## Architecture
/// ```
/// Native Engine (worker thread)
///       ↓
/// EngineChannel receives event
///       ↓
/// FlutterEventBus.post(event) ← Thread boundary
///       ↓
/// [Posted to platform thread via Future + SchedulerBinding]
///       ↓
/// Stream Broadcast (platform thread) ✅
///       ↓
/// ┌─────────────────────────────────────────┐
/// │ AudioService    │ IncomingCallProvider  │
/// │ Integration     │ ScreenPop             │
/// │ Recording       │ Any UI listener       │
/// └─────────────────────────────────────────┘
/// ```
class FlutterEventBus {
  FlutterEventBus._() {
    debugPrint('[FlutterEventBus] Instance created');
  }

  static final FlutterEventBus instance = FlutterEventBus._();

  final _eventController = StreamController<dynamic>.broadcast();

  /// Post an event to all listeners.
  ///
  /// This method is **thread-safe** and can be called from any thread.
  /// Events are automatically re-scheduled on the platform thread.
  void post<T>(T event) {
    // Schedule on platform thread using Future + SchedulerBinding
    // This ensures we switch from worker thread to platform thread
    Future(() {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _deliverEvent(event);
      });
    });
  }

  void _deliverEvent<T>(T event) {
    if (kDebugMode) {
      debugPrint('[FlutterEventBus] Delivering event: ${event.runtimeType}');
    }
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Listen to events of type [T].
  ///
  /// All events are guaranteed to be delivered on the platform thread.
  Stream<T> on<T>() {
    debugPrint('[FlutterEventBus] Listener registered for ${T.toString()}');
    return _eventController.stream.where((event) => event is T).cast<T>();
  }

  /// Get the total number of events posted (for debugging).
  int _eventCount = 0;

  /// Post an event and track statistics (for debugging).
  void postTracked<T>(T event, {String? context}) {
    _eventCount++;
    if (kDebugMode && context != null) {
      debugPrint('[FlutterEventBus] Posted event #$_eventCount: $context');
    }
    post(event);
  }

  void dispose() {
    debugPrint('[FlutterEventBus] Disposing, total events: $_eventCount');
    _eventController.close();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_settings_service.dart';
import '../core/call_event_service.dart';

class IncomingCallNotifier extends StateNotifier<Map<String, dynamic>?> {
  IncomingCallNotifier() : super(null) {
    debugPrint('[IncomingCallNotifier] Initializing, subscribing to events');
    // Subscribe to call events from the event bus
    _sub = CallEventService.instance.eventStream.listen(_onCallEvent);
  }

  StreamSubscription<CallEvent>? _sub;

  void _onCallEvent(CallEvent event) {
    debugPrint('[IncomingCallNotifier] Received event: ${event.state} ${event.direction}');
    final callState = event.state.toLowerCase();
    final direction = event.direction.toLowerCase();
    final dndEnabled = AppSettingsService.instance.dndEnabled;

    if (direction == 'incoming' && callState == 'callstate.ringing' && !dndEnabled) {
      debugPrint('[IncomingCallNotifier] Setting incoming call state');
      state = {
        'uri': event.uri,
        'direction': 'Incoming',
        'account_name': event.accountName ?? 'SIP Account',
        'account_user': event.accountUser ?? '',
        'extid': event.extid ?? '',
        'customer_data': event.customerData ?? {},
      };
      debugPrint('[IncomingCallNotifier] State updated: $state');
      return;
    }

    if (callState == 'callstate.incall' || callState == 'callstate.ended') {
      debugPrint('[IncomingCallNotifier] Clearing incoming call state');
      state = null;
    }
  }

  void clear() {
    debugPrint('[IncomingCallNotifier] Clear called');
    state = null;
  }

  @override
  void dispose() {
    debugPrint('[IncomingCallNotifier] Disposing');
    _sub?.cancel();
    super.dispose();
  }
}

final incomingCallProvider =
    StateNotifierProvider<IncomingCallNotifier, Map<String, dynamic>?>((ref) {
  debugPrint('[IncomingCallProvider] Creating notifier');
  final notifier = IncomingCallNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

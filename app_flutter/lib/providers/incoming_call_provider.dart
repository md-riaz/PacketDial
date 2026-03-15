import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_settings_service.dart';
import '../core/call_event_service.dart';
import '../core/integration_service.dart';
import '../models/customer_data.dart';

class IncomingCallNotifier extends StateNotifier<Map<String, dynamic>?> {
  IncomingCallNotifier() : super(null) {
    debugPrint('[IncomingCallNotifier] Initializing, subscribing to events');
    _sub = CallEventService.instance.eventStream.listen(_onCallEvent);
    // Listen for late-arriving CRM data and patch the active banner state
    _crmSub = IntegrationService.instance.onCustomerDataResolved
        .listen(_onCustomerDataResolved);
  }

  StreamSubscription<CallEvent>? _sub;
  StreamSubscription<CustomerData>? _crmSub;

  void _onCustomerDataResolved(CustomerData data) {
    // Only update if there is an active incoming call banner showing
    if (state == null) return;
    debugPrint('[IncomingCallNotifier] Late CRM data arrived: ${data.contactName}');
    state = {
      ...state!,
      'customer_data': data.toJson(),
    };
  }

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
    _crmSub?.cancel();
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

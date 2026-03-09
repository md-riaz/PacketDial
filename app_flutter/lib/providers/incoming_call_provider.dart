import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_settings_service.dart';
import '../core/engine_channel.dart';

class IncomingCallNotifier extends StateNotifier<Map<String, dynamic>?> {
  IncomingCallNotifier() : super(null) {
    _sub = EngineChannel.instance.eventStream.listen(_onEvent);
  }

  StreamSubscription<Map<String, dynamic>>? _sub;

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type != 'CallStateChanged') return;

    final payload = (event['payload'] as Map<String, dynamic>?) ?? {};
    final direction = (payload['direction'] as String? ?? '').toLowerCase();
    final callState = (payload['state'] as String? ?? '').toLowerCase();
    final dndEnabled = AppSettingsService.instance.dndEnabled;

    if (direction == 'incoming' && callState == 'ringing' && !dndEnabled) {
      state = {
        'uri': payload['uri'] as String? ?? '',
        'direction': 'Incoming',
        'account_name': payload['account_name'] as String? ?? 'SIP Account',
        'account_user': payload['account_user'] as String? ?? '',
        'extid': payload['extid'] as String? ?? '',
        'customer_data':
            payload['customer_data'] as Map<String, dynamic>? ?? {},
      };
      return;
    }

    if (callState == 'incall' || callState == 'ended') {
      state = null;
    }
  }

  void clear() {
    state = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final incomingCallProvider =
    StateNotifierProvider<IncomingCallNotifier, Map<String, dynamic>?>((ref) {
  final notifier = IncomingCallNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

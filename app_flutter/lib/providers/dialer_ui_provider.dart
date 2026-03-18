import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/engine_channel.dart';
import '../core/sip_uri_utils.dart';

class DialerUiState {
  final int? consultationCallId;
  final String? consultationUri;

  const DialerUiState({
    this.consultationCallId,
    this.consultationUri,
  });

  bool get hasConsultationCall => consultationCallId != null;
  String? get consultationDisplay => consultationUri != null
      ? SipUriUtils.friendlyName(consultationUri!)
      : null;

  DialerUiState copyWith({
    int? consultationCallId,
    String? consultationUri,
    bool clearConsultation = false,
  }) {
    if (clearConsultation) {
      return const DialerUiState();
    }
    return DialerUiState(
      consultationCallId: consultationCallId ?? this.consultationCallId,
      consultationUri: consultationUri ?? this.consultationUri,
    );
  }
}

class DialerUiNotifier extends StateNotifier<DialerUiState> {
  DialerUiNotifier() : super(const DialerUiState()) {
    _sub = EngineChannel.instance.eventStream.listen(_onEvent);
  }

  StreamSubscription<Map<String, dynamic>>? _sub;

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type != 'CallStateChanged') return;

    final payload = (event['payload'] as Map<String, dynamic>?) ?? {};
    final callId = (payload['call_id'] as num?)?.toInt();
    final callState = payload['state'] as String?;
    final direction = payload['direction'] as String?;
    final uri = payload['uri'] as String?;

    // Track consultation call when we start a new outgoing leg from hold.
    if (callId != null && callState == 'Ringing' && direction == 'Outgoing') {
      // Check if any existing call is on hold (the original call being consulted)
      final hasHeldCall = EngineChannel.instance.activeCalls.values
          .any((c) => c.onHold && c.callId != callId);
      if (hasHeldCall) {
        state = state.copyWith(
          consultationCallId: callId,
          consultationUri: uri,
        );
      }
    }

    // Refresh consultation display when answered.
    if (callId != null &&
        callState == 'InCall' &&
        callId == state.consultationCallId) {
      state = state.copyWith(consultationUri: uri);
    }

    // Clear consultation state when consultation leg ends.
    if (callState == 'Ended' && callId == state.consultationCallId) {
      state = state.copyWith(clearConsultation: true);
    }
  }

  void setConsultationCallId(int callId) {
    state = state.copyWith(consultationCallId: callId);
  }

  void clearConsultation() {
    state = state.copyWith(clearConsultation: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final dialerUiProvider =
    StateNotifierProvider<DialerUiNotifier, DialerUiState>((ref) {
  final notifier = DialerUiNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

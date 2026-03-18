import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/engine_channel.dart';
import '../core/sip_uri_utils.dart';

class DialerUiState {
  final int? consultationCallId;
  final String? consultationUri;
  final bool isConference;
  final int conferenceParticipantCount;
  /// True when the pending second leg was initiated via CONFERENCE (not TRANSFER).
  /// Suppresses the consultation banner and triggers auto-merge on answer.
  final bool pendingConferenceAdd;

  const DialerUiState({
    this.consultationCallId,
    this.consultationUri,
    this.isConference = false,
    this.conferenceParticipantCount = 0,
    this.pendingConferenceAdd = false,
  });

  bool get hasConsultationCall => consultationCallId != null && !pendingConferenceAdd;
  String? get consultationDisplay => consultationUri != null
      ? SipUriUtils.friendlyName(consultationUri!)
      : null;

  DialerUiState copyWith({
    int? consultationCallId,
    String? consultationUri,
    bool clearConsultation = false,
    bool? isConference,
    int? conferenceParticipantCount,
    bool? pendingConferenceAdd,
  }) {
    if (clearConsultation) {
      return DialerUiState(
        isConference: isConference ?? this.isConference,
        conferenceParticipantCount: conferenceParticipantCount ?? this.conferenceParticipantCount,
      );
    }
    return DialerUiState(
      consultationCallId: consultationCallId ?? this.consultationCallId,
      consultationUri: consultationUri ?? this.consultationUri,
      isConference: isConference ?? this.isConference,
      conferenceParticipantCount: conferenceParticipantCount ?? this.conferenceParticipantCount,
      pendingConferenceAdd: pendingConferenceAdd ?? this.pendingConferenceAdd,
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

    // Handle conference merge — collapse to single card
    if (type == 'ConferenceMerged') {
      final payload = (event['payload'] as Map<String, dynamic>?) ?? {};
      final callAId = (payload['call_a_id'] as num?)?.toInt();
      final callBId = (payload['call_b_id'] as num?)?.toInt();
      // 2 original legs + local = 3 participants (caller + 2 remote)
      final count = (callAId != null ? 1 : 0) + (callBId != null ? 1 : 0);
      state = state.copyWith(
        clearConsultation: true,
        isConference: true,
        conferenceParticipantCount: count + 1, // +1 for local user
      );
      return;
    }

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
      // If this was a conference add (not a transfer), auto-merge immediately.
      if (state.pendingConferenceAdd) {
        // Find the held call to merge with
        final heldCall = EngineChannel.instance.activeCalls.values
            .firstWhere((c) => c.onHold && c.callId != callId,
                orElse: () => EngineChannel.instance.activeCalls.values
                    .firstWhere((c) => c.callId != callId,
                        orElse: () => EngineChannel
                            .instance.activeCalls.values.first));
        EngineChannel.instance.mergeConference(heldCall.callId, callId);
        // ConferenceMerged event will update state; clear pending flag now
        state = state.copyWith(pendingConferenceAdd: false);
      } else {
        state = state.copyWith(consultationUri: state.consultationUri);
      }
    }

    // Clear consultation state when consultation leg ends.
    if (callState == 'Ended' && callId == state.consultationCallId) {
      state = state.copyWith(clearConsultation: true);
    }

    // Clear conference state when all calls have ended.
    if (callState == 'Ended' && state.isConference) {
      if (EngineChannel.instance.activeCalls.isEmpty) {
        state = const DialerUiState();
      }
    }
  }

  void setConsultationCallId(int callId) {
    state = state.copyWith(consultationCallId: callId);
  }

  /// Called when CONFERENCE button initiates a new leg — auto-merges on answer.
  void startConferenceAdd(int callId, String uri) {
    state = state.copyWith(
      consultationCallId: callId,
      consultationUri: uri,
      pendingConferenceAdd: true,
    );
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

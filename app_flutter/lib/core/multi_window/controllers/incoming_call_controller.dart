import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../engine_channel.dart';
import '../window_type.dart';

/// Manages the incoming call popup window lifecycle.
///
/// Listens to [EngineChannel] events and spawns/dismisses a secondary
/// popup window when an incoming call arrives or ends.
class IncomingCallController {
  IncomingCallController._();
  static final IncomingCallController instance = IncomingCallController._();

  WindowController? _popupController;
  StreamSubscription? _eventSub;
  bool _isPopupOpen = false;

  /// Start listening for incoming calls. Call this after engine boot.
  void init() {
    _eventSub?.cancel();
    _eventSub = EngineChannel.instance.eventStream.listen(_onEvent);
  }

  void dispose() {
    _eventSub?.cancel();
    _dismissPopup();
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final payload =
        (event['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    if (type == 'CallStateChanged') {
      final direction = payload['direction'] as String? ?? '';
      final state = payload['state'] as String? ?? '';

      if (direction == 'Incoming' && state == 'Ringing') {
        _showPopup(
          uri: payload['uri'] as String? ?? '',
          accountId: payload['account_id'] as String? ?? '',
        );
      } else if (state == 'InCall' || state == 'Ended') {
        _dismissPopup();
      }
    }
  }

  Future<void> _showPopup({
    required String uri,
    required String accountId,
  }) async {
    // Don't open multiple popups
    if (_isPopupOpen) return;

    try {
      // Find account name from engine channel
      final account = EngineChannel.instance.accounts[accountId];
      final accountName = account?.accountName ?? 'SIP Account';

      final payload = {
        'callData': {
          'uri': uri,
          'direction': 'Incoming',
          'account': accountName,
        },
      };

      final jsonStr = jsonEncode(payload);

      // Create the popup window
      _popupController = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: '${WindowType.incomingCall.key}|$jsonStr',
        ),
      );

      final id = _popupController!.windowId;
      _isPopupOpen = true;

      // Set up handler for answer/reject commands from the popup using low-level channel
      final channel = WindowMethodChannel(
        'mixin.one/window_controller/$id',
        mode: ChannelMode.unidirectional,
      );

      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'answer':
            _handleAnswer();
            break;
          case 'reject':
            _handleReject();
            break;
        }
        return null;
      });

      await _popupController!.show();
    } catch (e) {
      debugPrint('[IncomingCallController] Failed to create popup: $e');
      _isPopupOpen = false;
    }
  }

  void _dismissPopup() {
    if (!_isPopupOpen || _popupController == null) return;
    try {
      // In version 0.3.0, WindowController doesn't have a close() method.
      // We rely on bitsdojo_window in the sub-window to close itself,
      // or we hide it if we can't force close from here.
      _popupController!.hide();
    } catch (_) {}
    _popupController = null;
    _isPopupOpen = false;
  }

  void _handleAnswer() {
    EngineChannel.instance.engine.answerCall();
    // Popup will be dismissed when CallStateChanged → InCall arrives
  }

  void _handleReject() {
    EngineChannel.instance.engine.hangup();
    _dismissPopup();
  }
}

import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
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

      // Get main window bounds for positioning
      final mainWindowRect = await windowManager.getBounds();

      final payload = {
        'callData': {
          'uri': uri,
          'direction': 'Incoming',
          'account': accountName,
        },
        'parentBounds': {
          'x': mainWindowRect.left,
          'y': mainWindowRect.top,
          'w': mainWindowRect.width,
          'h': mainWindowRect.height,
        }
      };

      final jsonStr = jsonEncode(payload);

      // Create the popup window — it will configure its own size via windowManager
      _popupController = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: '${WindowType.incomingCall.key}|$jsonStr',
        ),
      );

      _isPopupOpen = true;

      await _popupController!.show();

      // Set up handler for answer/reject commands from the popup
      _popupController!.setWindowMethodHandler((call) async {
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
    } catch (e) {
      debugPrint('[IncomingCallController] Failed to create popup: $e');
      _isPopupOpen = false;
    }
  }

  void _dismissPopup() {
    if (!_isPopupOpen || _popupController == null) return;
    try {
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

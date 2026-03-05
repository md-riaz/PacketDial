import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../account_service.dart';
import '../../../models/account_schema.dart';
import '../window_type.dart';
import '../../../screens/accounts_screen.dart'; // for accountsListProvider

final accountSetupControllerProvider = Provider((ref) {
  final controller = AccountSetupController(ref);
  return controller;
});

class AccountSetupController {
  final Ref _ref;
  static final Map<String, AccountSetupController> _activeControllers = {};
  static bool _isListeningForChanges = false;

  String? _windowId;

  AccountSetupController(this._ref) {
    _ensureGlobalListener();
  }

  void _ensureGlobalListener() {
    if (_isListeningForChanges) return;
    _isListeningForChanges = true;

    onWindowsChanged.listen((_) async {
      final all = await WindowController.getAll();
      final activeIds = all.map((w) => w.windowId).toSet();

      // Cleanup any controllers whose windows are gone
      final goneIds = _activeControllers.keys
          .where((id) => !activeIds.contains(id))
          .toList();

      for (final id in goneIds) {
        final ctrl = _activeControllers.remove(id);
        if (ctrl?._windowId == id) {
          ctrl?._windowId = null;
        }
      }
    });
  }

  void _setupHandler(String windowId) {
    // We use WindowMethodChannel directly to bypass the "current window" assertion
    // in the high-level WindowController.setWindowMethodHandler method.
    final channel = WindowMethodChannel(
      'mixin.one/window_controller/$windowId',
      mode: ChannelMode.unidirectional,
    );

    channel.setMethodCallHandler((call) async {
      try {
        if (call.method == 'tryRegister') {
          final args =
              jsonDecode(call.arguments as String) as Map<String, dynamic>;
          final result = await _ref.read(accountServiceProvider).tryRegister(
                username: args['username'] as String,
                password: args['password'] as String,
                server: args['server'] as String,
                transport: args['transport'] as String? ?? 'udp',
                domain: args['domain'] as String? ?? '',
                proxy: args['proxy'] as String? ?? '',
              );
          return jsonEncode({
            'success': result.success,
            'errorReason': result.errorReason,
          });
        } else if (call.method == 'saveAccount') {
          final args =
              jsonDecode(call.arguments as String) as Map<String, dynamic>;
          final schema = AccountSchema.fromJson(args);
          await _ref.read(accountServiceProvider).saveAccount(schema);
          _ref.read(accountServiceProvider).register(schema);
          _ref.invalidate(accountsListProvider);

          // The window will close itself using bitsdojo_window after receiving null
          _activeControllers.remove(windowId);
          if (_windowId == windowId) _windowId = null;
          return null;
        } else if (call.method == 'close') {
          _activeControllers.remove(windowId);
          if (_windowId == windowId) _windowId = null;
          return null;
        }
      } catch (e) {
        debugPrint(
            '[AccountSetupController] IPC error from window $windowId: $e');
      }
      return null;
    });
  }

  Future<void> showWindow([AccountSchema? existing]) async {
    if (_windowId != null) {
      // Proactive check if window still exists (covers late events)
      final all = await WindowController.getAll();
      final exists = all.any((w) => w.windowId == _windowId);
      if (exists) {
        // Already open, just show/focus (implementation details of focusing depend on plugin)
        final window = WindowController.fromWindowId(_windowId!);
        await window.show();
        return;
      } else {
        // State was stale, reset
        debugPrint(
            '[AccountSetupController] Detected stale windowId, resetting.');
        _windowId = null;
        _activeControllers.removeWhere((id, ctrl) => ctrl == this);
      }
    }

    final payload = {
      'existing': existing?.toJson(),
    };

    final jsonStr = jsonEncode(payload);
    final window = await WindowController.create(
      WindowConfiguration(
        arguments: '${WindowType.accountSetup.key}|$jsonStr',
      ),
    );

    final id = window.windowId;
    _windowId = id;
    _activeControllers[id] = this;

    _setupHandler(id);

    // Initial show
    await window.show();
  }
}

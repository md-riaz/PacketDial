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
      debugPrint(
          '[AccountSetupController] Method handler for $windowId called: ${call.method}');
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
          debugPrint('[AccountSetupController] Saving account via IPC...');
          final args =
              jsonDecode(call.arguments as String) as Map<String, dynamic>;
          final schema = AccountSchema.fromJson(args);

          final service = _ref.read(accountServiceProvider);
          if (service.isar == null) {
            debugPrint(
                '[AccountSetupController] ERROR: Isar not ready in main process!');
            return jsonEncode({'success': false, 'error': 'Isar not ready'});
          }

          await service.saveAccount(schema);
          service.register(schema);
          _ref.invalidate(accountsListProvider);

          debugPrint('[AccountSetupController] Account saved successfully');

          // Don't cleanup here - let the window close naturally
          return jsonEncode({'success': true});
        } else if (call.method == 'close') {
          debugPrint(
              '[AccountSetupController] Close request received for $windowId');
          // Cleanup immediately - window will close on its own
          _activeControllers.remove(windowId);
          if (_windowId == windowId) _windowId = null;
          return null;
        }
      } catch (e, stack) {
        debugPrint(
            '[AccountSetupController] CRITICAL IPC ERROR from window $windowId: $e');
        debugPrint(stack.toString());
        return jsonEncode({'success': false, 'error': e.toString()});
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
        await window.show().catchError((e) {
          debugPrint('[AccountSetupController] Error showing existing window: $e');
        });
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

    try {
      final window = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: false,
          arguments: '${WindowType.accountSetup.key}|$jsonStr',
        ),
      );

      final id = window.windowId;
      _windowId = id;
      _activeControllers[id] = this;

      _setupHandler(id);
    } catch (e) {
      debugPrint('[AccountSetupController] Failed to create window: $e');
      _windowId = null;
    }
  }
}

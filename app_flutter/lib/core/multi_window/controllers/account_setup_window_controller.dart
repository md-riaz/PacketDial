import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../account_service.dart';
import '../../../models/account_schema.dart';
import '../window_type.dart';

/// Provider for the account setup window controller
final accountSetupWindowControllerProvider = Provider((ref) {
  return AccountSetupWindowController(ref);
});

/// Optimized account setup controller that reuses a single window
/// and changes content dynamically instead of creating new windows.
class AccountSetupWindowController {
  final Ref _ref;
  static AccountSetupWindowController? _instance;

  WindowController? _windowController;
  String? _windowId;
  bool _isWindowReady = false;

  AccountSetupWindowController(this._ref) {
    _instance = this;
  }

  /// Get the singleton instance (for use outside Riverpod)
  static AccountSetupWindowController? get instance => _instance;

  /// Get or create the account setup window
  Future<WindowController> _ensureWindow() async {
    // Check if existing window is still valid
    if (_windowId != null) {
      try {
        final all = await WindowController.getAll();
        final exists = all.any((w) => w.windowId == _windowId);
        if (exists) {
          final window = WindowController.fromWindowId(_windowId!);
          await window.show();
          return window;
        }
      } catch (e) {
        debugPrint('[AccountSetupWindowController] Error checking window: $e');
      }
      // Window is gone, cleanup
      _windowController = null;
      _windowId = null;
      _isWindowReady = false;
    }

    // Create new window
    final payload = {'existing': null, 'action': 'show'};
    final jsonStr = jsonEncode(payload);

    _windowController = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: false,
        arguments: '${WindowType.accountSetup.key}|$jsonStr',
      ),
    );

    _windowId = _windowController!.windowId;
    _setupHandler();

    return _windowController!;
  }

  void _setupHandler() {
    if (_windowId == null) return;

    final channel = WindowMethodChannel(
      'mixin.one/window_controller/$_windowId',
      mode: ChannelMode.unidirectional,
    );

    channel.setMethodCallHandler((call) async {
      try {
        if (call.method == 'tryRegister') {
          final args =
              jsonDecode(call.arguments as String) as Map<String, dynamic>;
          final service = _ref.read(accountServiceProvider);
          final result = await service.tryRegister(
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

          final service = _ref.read(accountServiceProvider);
          if (service.isar == null) {
            return jsonEncode({'success': false, 'error': 'Isar not ready'});
          }

          await service.saveAccount(schema);
          service.register(schema);
          
          return jsonEncode({'success': true});
        } else if (call.method == 'windowReady') {
          _isWindowReady = true;
          debugPrint('[AccountSetupWindowController] Window is ready');
        } else if (call.method == 'close') {
          _windowController = null;
          _windowId = null;
          _isWindowReady = false;
        }
      } catch (e, stack) {
        debugPrint('[AccountSetupWindowController] Error: $e');
        debugPrint(stack.toString());
        return jsonEncode({'success': false, 'error': e.toString()});
      }
      return null;
    });
  }

  /// Show the account setup window with optional existing account for editing
  Future<void> showWindow(AccountSchema? existing) async {
    final window = await _ensureWindow();

    // Send content update to window
    final payload = {
      'existing': existing?.toJson(),
      'action': 'show',
    };

    try {
      await window.invokeMethod('setContent', jsonEncode(payload));
      await window.show();
    } catch (e) {
      debugPrint('[AccountSetupWindowController] Error updating content: $e');
      // If update failed, create a new window
      _windowController = null;
      _windowId = null;
      await showWindow(existing);
    }
  }

  /// Close the window
  Future<void> closeWindow() async {
    if (_windowController == null) return;

    try {
      await _windowController?.invokeMethod('close', '');
    } catch (e) {
      debugPrint('[AccountSetupWindowController] Error closing: $e');
    }

    _windowController = null;
    _windowId = null;
    _isWindowReady = false;
  }

  /// Check if window is open
  bool get isOpen => _windowId != null && _windowController != null;
}

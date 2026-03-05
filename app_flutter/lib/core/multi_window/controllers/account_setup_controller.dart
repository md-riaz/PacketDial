import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../account_service.dart';
import '../../../models/account_schema.dart';
import '../window_type.dart';
import '../../../screens/accounts_screen.dart'; // for accountsListProvider

final accountSetupControllerProvider =
    Provider((ref) => AccountSetupController(ref));

class AccountSetupController {
  final Ref _ref;
  WindowController? _setupWindow;

  AccountSetupController(this._ref);

  Future<void> showWindow([AccountSchema? existing]) async {
    if (_setupWindow != null) {
      try {
        await _setupWindow!.show();
      } catch (_) {}
      return;
    }

    // Get main window bounds
    final mainWindowRect = await windowManager.getBounds();

    final payload = {
      'existing': existing?.toJson(),
      'parentBounds': {
        'x': mainWindowRect.left,
        'y': mainWindowRect.top,
        'w': mainWindowRect.width,
        'h': mainWindowRect.height,
      }
    };

    final jsonStr = jsonEncode(payload);
    _setupWindow = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: '${WindowType.accountSetup.key}|$jsonStr',
      ),
    );

    await _setupWindow!.show();

    _setupWindow!.setWindowMethodHandler((call) async {
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
          _setupWindow = null;
          return null;
        }
      } catch (e) {
        debugPrint('[AccountSetupController] IPC error: $e');
      }
      return null;
    });
  }
}

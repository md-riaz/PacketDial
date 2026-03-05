import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../../screens/account_setup_window.dart';
import '../../screens/incoming_call_popup.dart';
import '../../models/account_schema.dart';
import 'window_type.dart';

class WindowRouter {
  static Widget? getAppForArgs(
      String windowArgs, WindowController windowController) {
    if (!windowArgs.contains('|')) return null;

    final parts = windowArgs.split('|');
    final typeStr = parts.first;
    final jsonStr = parts.sublist(1).join('|');

    final type = WindowType.fromString(typeStr);

    switch (type) {
      case WindowType.incomingCall:
        Map<String, dynamic> callInfo = {};
        try {
          final payload = jsonDecode(jsonStr) as Map<String, dynamic>;
          callInfo = payload['callData'] as Map<String, dynamic>? ?? {};
        } catch (_) {}
        return IncomingCallPopup(
          windowController: windowController,
          callInfo: callInfo,
        );

      case WindowType.accountSetup:
        AccountSchema? existing;
        try {
          final payload = jsonDecode(jsonStr) as Map<String, dynamic>;
          final accMap = payload['existing'] as Map<String, dynamic>?;
          if (accMap != null && accMap.isNotEmpty) {
            existing = AccountSchema.fromJson(accMap);
          }
        } catch (_) {}
        return AccountSetupWindow(
          windowController: windowController,
          existing: existing,
        );

      case WindowType.unknown:
        return null;
    }
  }
}

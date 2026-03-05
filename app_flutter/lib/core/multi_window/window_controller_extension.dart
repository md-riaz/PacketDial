import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

/// Extension to add window control methods to WindowController
/// Following the desktop_multi_window plugin documentation pattern
extension WindowControllerExtension on WindowController {
  /// Initialize the window method handler for this window
  /// Must be called in each sub-window's initialization
  Future<void> initWindowMethodHandler() async {
    return await setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'window_close':
          return await windowManager.close();
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }

  /// Close this window from another window
  Future<void> closeWindow() async {
    return await invokeMethod('window_close');
  }
}

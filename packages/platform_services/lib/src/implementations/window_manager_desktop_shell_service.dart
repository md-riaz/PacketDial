import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../interfaces/desktop_shell_service.dart';

class WindowManagerDesktopShellService implements DesktopShellService {
  WindowManagerDesktopShellService({required DesktopShellService fallback})
    : _fallback = fallback;

  final DesktopShellService _fallback;

  @override
  Future<void> enableTray() async {
    try {
      await trayManager.setToolTip('PacketDial');
    } catch (_) {
      await _fallback.enableTray();
    }
  }

  @override
  Future<void> focusWindow() async {
    try {
      await windowManager.focus();
    } catch (_) {
      await _fallback.focusWindow();
    }
  }

  @override
  Future<void> hideWindow() async {
    try {
      await windowManager.hide();
    } catch (_) {
      await _fallback.hideWindow();
    }
  }

  @override
  Future<void> showWindow() async {
    try {
      await windowManager.show();
    } catch (_) {
      await _fallback.showWindow();
    }
  }
}

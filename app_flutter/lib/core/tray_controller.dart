import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayController with TrayListener {
  static final TrayController instance = TrayController._();
  TrayController._();
  DateTime? _initializedAt;

  Future<void> init() async {
    // In release builds, assets are under data/flutter_assets.
    // Prefer ICO on Windows (tray quality), then fall back to PNG.
    final iconPath = _resolveTrayIconPath();
    await trayManager.setIcon(iconPath);

    List<MenuItem> items = [
      MenuItem(
        key: 'show_window',
        label: 'Show PacketDial',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit_app',
        label: 'Exit',
      ),
    ];
    await trayManager.setContextMenu(Menu(items: items));
    trayManager.addListener(this);
    _initializedAt = DateTime.now();
  }

  String _resolveTrayIconPath() {
    if (!Platform.isWindows) return 'assets/app_icon.png';

    const candidates = [
      'assets/app_icon.ico',
      'data/flutter_assets/assets/app_icon.ico',
      'assets/app_icon.png',
      'data/flutter_assets/assets/app_icon.png',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return 'assets/app_icon.png';
  }

  @override
  void onTrayIconMouseDown() async {
    debugPrint('[TrayController] Tray icon left-click: show/focus window');
    await showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    debugPrint('[TrayController] Tray icon right-click: open context menu');
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    debugPrint('[TrayController] Menu click: ${menuItem.key}');
    if (menuItem.key == 'show_window') {
      await showWindow();
    } else if (menuItem.key == 'exit_app') {
      final initializedAt = _initializedAt;
      if (initializedAt != null &&
          DateTime.now().difference(initializedAt).inSeconds < 3) {
        debugPrint(
            '[TrayController] Ignoring early exit_app click (startup tray noise)');
        return;
      }
      debugPrint('[TrayController] Exiting app via tray menu');
      await windowManager.destroy();
    }
  }

  Future<void> showWindow() async {
    await windowManager.setSkipTaskbar(false);
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideToTray() async {
    await windowManager.setSkipTaskbar(true);
    await windowManager.hide();
  }
}

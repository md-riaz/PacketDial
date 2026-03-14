import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;

class TrayController with TrayListener {
  static final TrayController instance = TrayController._();
  TrayController._();
  DateTime? _initializedAt;

  Future<void> init() async {
    // In release builds, assets are under data/flutter_assets.
    // Prefer ICO on Windows (tray quality), then fall back to PNG.
    final iconPath = getBestIconPath();
    debugPrint('[TrayController] Initializing tray with icon: $iconPath');
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

  String getBestIconPath() {
    if (!Platform.isWindows) return 'assets/app_icon.png';

    final exeDir = p.dirname(Platform.resolvedExecutable);

    // 1. Check for icon.ico next to EXE (typical for installer/portable)
    final installerIcon = p.join(exeDir, 'icon.ico');
    if (File(installerIcon).existsSync()) return installerIcon;

    // 2. Check for app_icon.ico next to EXE (as backup)
    final appIconIco = p.join(exeDir, 'app_icon.ico');
    if (File(appIconIco).existsSync()) return appIconIco;

    // 3. Check standard Flutter asset location in built app
    final flutterAssetsIco =
        p.join(exeDir, 'data', 'flutter_assets', 'assets', 'app_icon.ico');
    if (File(flutterAssetsIco).existsSync()) return flutterAssetsIco;

    // 4. Fallback for debugger/hot-reload (relative to current working dir)
    if (File('assets/app_icon.ico').existsSync()) return 'assets/app_icon.ico';

    // 5. Hardcoded asset path (plugin might resolve it internally)
    return 'assets/app_icon.ico';
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

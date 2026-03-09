import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayController with TrayListener {
  static final TrayController instance = TrayController._();
  TrayController._();

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
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      await windowManager.destroy();
      exit(0);
    }
  }
}

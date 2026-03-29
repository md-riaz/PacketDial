import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DesktopShellCoordinator with TrayListener, WindowListener {
  DesktopShellCoordinator._();

  static final DesktopShellCoordinator instance = DesktopShellCoordinator._();

  bool _initialized = false;
  bool _quitting = false;

  Future<void> initialize() async {
    if (_initialized ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return;
    }

    trayManager.addListener(this);
    windowManager.addListener(this);

    await trayManager.setToolTip('PacketDial');
    final iconPath = await _resolveTrayIcon();
    if (iconPath != null) {
      await trayManager.setIcon(iconPath);
    }
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Show PacketDial'),
          MenuItem(key: 'hide', label: 'Hide to Tray'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );

    _initialized = true;
  }

  Future<void> dispose() async {
    if (!_initialized) {
      return;
    }
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
    _initialized = false;
  }

  @override
  Future<void> onWindowClose() async {
    if (_quitting) {
      await dispose();
      await windowManager.destroy();
      return;
    }

    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  @override
  Future<void> onTrayIconMouseDown() async {
    await _toggleVisibility();
  }

  @override
  Future<void> onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await _showWindow();
        return;
      case 'hide':
        await windowManager.hide();
        await windowManager.setSkipTaskbar(true);
        return;
      case 'quit':
        _quitting = true;
        await windowManager.setPreventClose(false);
        await dispose();
        await windowManager.close();
        return;
      default:
        return;
    }
  }

  Future<void> _toggleVisibility() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
      return;
    }
    await _showWindow();
  }

  Future<void> _showWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<String?> _resolveTrayIcon() async {
    final candidates = <String>[
      '${Directory.current.path}${Platform.pathSeparator}windows${Platform.pathSeparator}runner${Platform.pathSeparator}resources${Platform.pathSeparator}app_icon.ico',
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}app_icon.ico',
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}app_icon.ico',
    ];

    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }
}

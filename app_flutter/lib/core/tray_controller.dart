import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayController with TrayListener {
  static final TrayController instance = TrayController._();
  TrayController._();

  Future<void> init() async {
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
    );

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

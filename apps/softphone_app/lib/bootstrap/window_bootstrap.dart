import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

class WindowBootstrap {
  static Future<void> maybeInit() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }

    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'PacketDial',
      minimumSize: Size(1080, 680),
      size: Size(1280, 780),
      center: true,
      backgroundColor: Color(0x00FFFFFF),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await windowManager.setPreventClose(true);
  }
}

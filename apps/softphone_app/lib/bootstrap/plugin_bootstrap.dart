import 'package:platform_services/platform_services.dart';

import 'app_services.dart';

class PluginBootstrap {
  static Future<void> initialize([PlatformServicesBundle? services]) async {
    final resolved = services ?? AppServices.instance;
    await resolved.permissions.ensureNotificationsIfNeeded();
    await resolved.permissions.ensureMicrophone();
  }
}

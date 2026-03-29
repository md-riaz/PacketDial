import 'package:platform_services/platform_services.dart';

import 'app_services.dart';

class NotificationsBootstrap {
  static Future<void> initialize([AppNotifications? service]) async {
    final notifications = service ?? AppServices.instance.notifications;
    if (notifications is FlutterLocalNotificationsService) {
      await notifications.initialize();
    }
  }
}

class NotificationActionEvent {
  const NotificationActionEvent({
    required this.actionId,
    required this.payload,
  });

  final String actionId;
  final String? payload;
}

abstract class AppNotifications {
  Stream<NotificationActionEvent> get actions;

  Future<void> showIncomingCall({
    required int id,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancel(int id);
}

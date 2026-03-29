import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../interfaces/app_notifications.dart';

class FlutterLocalNotificationsService implements AppNotifications {
  FlutterLocalNotificationsService({required AppNotifications fallback})
    : _fallback = fallback;

  final AppNotifications _fallback;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationActionEvent> _actions =
      StreamController<NotificationActionEvent>.broadcast();
  bool _initialized = false;

  static const String answerActionId = 'answer_call';
  static const String rejectActionId = 'reject_call';
  static const String incomingCategoryId = 'incoming_call_category';

  @override
  Stream<NotificationActionEvent> get actions => _actions.stream;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            notificationCategories: <DarwinNotificationCategory>[
              DarwinNotificationCategory(
                incomingCategoryId,
                actions: <DarwinNotificationAction>[
                  DarwinNotificationAction.plain(answerActionId, 'Answer'),
                  DarwinNotificationAction.plain(
                    rejectActionId,
                    'Reject',
                    options: <DarwinNotificationActionOption>{
                      DarwinNotificationActionOption.destructive,
                    },
                  ),
                ],
              ),
            ],
          ),
          windows: const WindowsInitializationSettings(
            appName: 'PacketDial',
            appUserModelId: 'PacketDial.Softphone',
            guid: 'ddf60d9d-16d9-4ad1-9a24-0b79524515dc',
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          _actions.add(
            NotificationActionEvent(
              actionId: response.actionId ?? '',
              payload: response.payload,
            ),
          );
        },
      );
      _initialized = true;
    } catch (_) {}
  }

  @override
  Future<void> cancel(int id) async {
    if (!_initialized) {
      await initialize();
    }
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      await _fallback.cancel(id);
    }
  }

  @override
  Future<void> showIncomingCall({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'incoming_calls',
            'Incoming Calls',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(answerActionId, 'Answer'),
              AndroidNotificationAction(
                rejectActionId,
                'Reject',
                cancelNotification: true,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
            categoryIdentifier: incomingCategoryId,
          ),
          windows: WindowsNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (_) {
      await _fallback.showIncomingCall(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
    }
  }
}

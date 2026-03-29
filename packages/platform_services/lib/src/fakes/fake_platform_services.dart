import 'dart:async';

import '../interfaces/app_notifications.dart';
import '../interfaces/audio_session_service.dart';
import '../interfaces/connectivity_service.dart';
import '../interfaces/desktop_shell_service.dart';
import '../interfaces/permissions_service.dart';
import '../interfaces/secure_secrets_store.dart';

class FakePlatformServices {
  FakePlatformServices()
    : permissions = _FakePermissionsService(),
      secureStorage = _FakeSecretsStore(),
      connectivity = _FakeConnectivityService(),
      notifications = _FakeNotificationsService(),
      audioSession = _FakeAudioSessionService(),
      desktopShell = _FakeDesktopShellService();

  final PermissionsService permissions;
  final SecureSecretsStore secureStorage;
  final ConnectivityService connectivity;
  final AppNotifications notifications;
  final AudioSessionService audioSession;
  final DesktopShellService desktopShell;
}

class _FakePermissionsService implements PermissionsService {
  @override
  Future<bool> ensureMicrophone() async => true;

  @override
  Future<bool> ensureNotificationsIfNeeded() async => true;
}

class _FakeSecretsStore implements SecureSecretsStore {
  final Map<String, String> _secrets = <String, String>{};

  @override
  Future<void> deleteSipPassword(String accountId) async {
    _secrets.remove(accountId);
  }

  @override
  Future<String?> readSipPassword(String accountId) async =>
      _secrets[accountId];

  @override
  Future<void> writeSipPassword(String accountId, String value) async {
    _secrets[accountId] = value;
  }
}

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<List<String>> currentLinks() async => const <String>['wifi', 'vpn'];

  @override
  Stream<List<String>> watchLinks() async* {
    yield const <String>['wifi', 'vpn'];
  }
}

class _FakeNotificationsService implements AppNotifications {
  final StreamController<NotificationActionEvent> _actions =
      StreamController<NotificationActionEvent>.broadcast();

  @override
  Stream<NotificationActionEvent> get actions => _actions.stream;

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> showIncomingCall({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {}
}

class _FakeAudioSessionService implements AudioSessionService {
  @override
  Future<void> configureForVoice() async {}
}

class _FakeDesktopShellService implements DesktopShellService {
  @override
  Future<void> enableTray() async {}

  @override
  Future<void> focusWindow() async {}

  @override
  Future<void> hideWindow() async {}

  @override
  Future<void> showWindow() async {}
}

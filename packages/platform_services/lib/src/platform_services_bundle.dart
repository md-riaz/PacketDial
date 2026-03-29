import 'fakes/fake_platform_services.dart';
import 'implementations/connectivity_plus_service.dart';
import 'implementations/flutter_local_notifications_service.dart';
import 'implementations/flutter_secure_secrets_store.dart';
import 'implementations/permission_handler_service.dart';
import 'implementations/simple_audio_session_service.dart';
import 'implementations/window_manager_desktop_shell_service.dart';
import 'interfaces/app_notifications.dart';
import 'interfaces/audio_session_service.dart';
import 'interfaces/connectivity_service.dart';
import 'interfaces/desktop_shell_service.dart';
import 'interfaces/permissions_service.dart';
import 'interfaces/secure_secrets_store.dart';

class PlatformServicesBundle {
  PlatformServicesBundle({
    required this.permissions,
    required this.secureStorage,
    required this.connectivity,
    required this.notifications,
    required this.audioSession,
    required this.desktopShell,
  });

  factory PlatformServicesBundle.create() {
    final fake = FakePlatformServices();
    return PlatformServicesBundle(
      permissions: PermissionHandlerService(fallback: fake.permissions),
      secureStorage: FlutterSecureSecretsStore(fallback: fake.secureStorage),
      connectivity: ConnectivityPlusService(fallback: fake.connectivity),
      notifications: FlutterLocalNotificationsService(
        fallback: fake.notifications,
      ),
      audioSession: SimpleAudioSessionService(fallback: fake.audioSession),
      desktopShell: WindowManagerDesktopShellService(
        fallback: fake.desktopShell,
      ),
    );
  }

  final PermissionsService permissions;
  final SecureSecretsStore secureStorage;
  final ConnectivityService connectivity;
  final AppNotifications notifications;
  final AudioSessionService audioSession;
  final DesktopShellService desktopShell;
}

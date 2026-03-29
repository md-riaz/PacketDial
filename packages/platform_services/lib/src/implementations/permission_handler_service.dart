import 'package:permission_handler/permission_handler.dart';

import '../interfaces/permissions_service.dart';

class PermissionHandlerService implements PermissionsService {
  PermissionHandlerService({required PermissionsService fallback})
    : _fallback = fallback;

  final PermissionsService _fallback;

  @override
  Future<bool> ensureMicrophone() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted || status.isLimited;
    } catch (_) {
      return _fallback.ensureMicrophone();
    }
  }

  @override
  Future<bool> ensureNotificationsIfNeeded() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted || status.isLimited || status.isDenied;
    } catch (_) {
      return _fallback.ensureNotificationsIfNeeded();
    }
  }
}

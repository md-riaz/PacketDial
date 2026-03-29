abstract class PermissionsService {
  Future<bool> ensureMicrophone();
  Future<bool> ensureNotificationsIfNeeded();
}

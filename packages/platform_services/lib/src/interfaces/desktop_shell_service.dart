abstract class DesktopShellService {
  Future<void> showWindow();
  Future<void> hideWindow();
  Future<void> focusWindow();
  Future<void> enableTray();
}

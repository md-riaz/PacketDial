import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Persists window position, size, and always-on-top preference.
class WindowPrefs {
  static const _kX = 'window_x';
  static const _kY = 'window_y';
  static const _kW = 'window_w';
  static const _kH = 'window_h';
  static const _kAlwaysOnTop = 'always_on_top';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Always-on-top ──────────────────────────────────────────────────────

  bool get alwaysOnTop => _prefs.getBool(_kAlwaysOnTop) ?? false;

  Future<void> setAlwaysOnTop(bool value) async {
    await _prefs.setBool(_kAlwaysOnTop, value);
    await windowManager.setAlwaysOnTop(value);
  }

  /// Apply saved always-on-top state to the window.
  Future<void> applyAlwaysOnTop() async {
    await windowManager.setAlwaysOnTop(alwaysOnTop);
  }

  // ── Window geometry ────────────────────────────────────────────────────

  bool get hasSavedGeometry => _prefs.containsKey(_kW);

  Future<void> saveGeometry() async {
    final pos = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await _prefs.setDouble(_kX, pos.dx);
    await _prefs.setDouble(_kY, pos.dy);
    await _prefs.setDouble(_kW, size.width);
    await _prefs.setDouble(_kH, size.height);
  }

  Future<void> restoreGeometry() async {
    if (!hasSavedGeometry) return;
    final w = _prefs.getDouble(_kW) ?? 360;
    final h = _prefs.getDouble(_kH) ?? 760;
    final x = _prefs.getDouble(_kX);
    final y = _prefs.getDouble(_kY);

    await windowManager.setSize(Size(w, h));
    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }
  }
}

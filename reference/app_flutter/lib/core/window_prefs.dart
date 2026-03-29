import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'app_theme.dart';
import 'path_provider_service.dart';

/// Persists window position, size, and always-on-top preference.
class WindowPrefs {
  static final WindowPrefs _instance = WindowPrefs._internal();
  factory WindowPrefs() => _instance;
  WindowPrefs._internal();

  static WindowPrefs get instance => _instance;
  static const _kX = 'window_x';
  static const _kY = 'window_y';
  static const _kW = 'window_w';
  static const _kH = 'window_h';
  static const _kAlwaysOnTop = 'always_on_top';
  static const _kResizeLocked = 'resize_locked';

  Map<String, dynamic> _data = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        _data = jsonDecode(content) as Map<String, dynamic>;
      } else {
        // Initialize with default values
        _data = {
          _kAlwaysOnTop: false,
        };
        await _save();
      }
    } catch (e) {
      debugPrint('[WindowPrefs] Error initializing: $e');
    }
    _initialized = true;
  }

  Future<File> _getFile() async {
    final dir = await PathProviderService.instance.getDataDirectory();
    return File('${dir.path}/window_prefs.json');
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(_data), flush: true);
    } catch (e) {
      debugPrint('[WindowPrefs] Error saving: $e');
    }
  }

  // ── Always-on-top ──────────────────────────────────────────────────────

  bool get alwaysOnTop => _data[_kAlwaysOnTop] as bool? ?? false;

  Future<void> setAlwaysOnTop(bool value) async {
    _data[_kAlwaysOnTop] = value;
    await _save();
    await windowManager.setAlwaysOnTop(value);
  }

  /// Apply saved always-on-top state to the window.
  Future<void> applyAlwaysOnTop() async {
    await windowManager.setAlwaysOnTop(alwaysOnTop);
  }

  // ── Resize lock ───────────────────────────────────────────────────────

  bool get resizeLocked => _data[_kResizeLocked] as bool? ?? true;

  Future<void> setResizeLocked(bool value) async {
    _data[_kResizeLocked] = value;
    await _save();
    await applyResizeLock();
  }

  /// Enforce or release the resize lock on the OS window.
  Future<void> applyResizeLock() async {
    if (resizeLocked) {
      final size = await windowManager.getSize();
      final w = size.width.clamp(
          AppTheme.minWindowSize.width, AppTheme.maxWindowSize.width);
      final h = size.height.clamp(
          AppTheme.minWindowSize.height, AppTheme.maxWindowSize.height);
      await windowManager.setMinimumSize(Size(w, h));
      await windowManager.setMaximumSize(Size(w, h));
    } else {
      // Unlocked: only enforce the minimum, no max — content centering handles large windows
      await windowManager.setMinimumSize(AppTheme.minWindowSize);
      await windowManager.setMaximumSize(const Size(32767, 32767));
    }
  }

  // ── Window geometry ────────────────────────────────────────────────────

  bool get hasSavedGeometry => _data.containsKey(_kW);

  Future<void> saveGeometry() async {
    final pos = await windowManager.getPosition();
    final size = await windowManager.getSize();
    _data[_kX] = pos.dx;
    _data[_kY] = pos.dy;
    _data[_kW] = size.width;
    _data[_kH] = size.height;
    await _save();
  }

  Future<void> restoreGeometry() async {
    if (!hasSavedGeometry) return;
    var w = (_data[_kW] as num?)?.toDouble() ?? AppTheme.defaultWindowSize.width;
    var h = (_data[_kH] as num?)?.toDouble() ?? AppTheme.defaultWindowSize.height;
    final x = (_data[_kX] as num?)?.toDouble();
    final y = (_data[_kY] as num?)?.toDouble();

    // Clamp to at least the minimum — prevents restoring a too-small window
    w = w.clamp(AppTheme.minWindowSize.width, double.infinity);
    h = h.clamp(AppTheme.minWindowSize.height, double.infinity);

    await windowManager.setSize(Size(w, h));
    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/window_prefs.dart';

final windowPrefsProvider = NotifierProvider<WindowPrefsNotifier, bool>(() {
  return WindowPrefsNotifier();
});

class WindowPrefsNotifier extends Notifier<bool> {
  late WindowPrefs _prefs;

  @override
  bool build() {
    _prefs = WindowPrefs.instance;
    return _prefs.alwaysOnTop;
  }

  Future<void> toggleAlwaysOnTop() async {
    final newValue = !_prefs.alwaysOnTop;
    await _prefs.setAlwaysOnTop(newValue);
    state = newValue;
  }

  bool get alwaysOnTop => _prefs.alwaysOnTop;
}

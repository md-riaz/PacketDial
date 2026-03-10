import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_settings_service.dart';

class AppSettingsData {
  final List<Map<String, dynamic>> codecPriorities;
  final int dtmfMethod;
  final bool autoAnswerEnabled;
  final bool dndEnabled;
  final bool blfEnabled;

  AppSettingsData({
    required this.codecPriorities,
    required this.dtmfMethod,
    required this.autoAnswerEnabled,
    required this.dndEnabled,
    required this.blfEnabled,
  });

  factory AppSettingsData.defaultSettings() {
    return AppSettingsData(
      codecPriorities: const [],
      dtmfMethod: 1,
      autoAnswerEnabled: false,
      dndEnabled: false,
      blfEnabled: true,
    );
  }

  factory AppSettingsData.fromService(AppSettingsService service) {
    return AppSettingsData(
      codecPriorities: service.codecPriorities,
      dtmfMethod: service.dtmfMethod,
      autoAnswerEnabled: service.autoAnswerEnabled,
      dndEnabled: service.dndEnabled,
      blfEnabled: service.blfEnabled,
    );
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsData>(() {
  return AppSettingsNotifier();
});

class AppSettingsNotifier extends Notifier<AppSettingsData> {
  late AppSettingsService _service;

  @override
  AppSettingsData build() {
    _service = AppSettingsService.instance;
    return AppSettingsData.fromService(_service);
  }

  void _refresh() {
    state = AppSettingsData.fromService(_service);
  }

  Future<void> reloadSettings() async {
    await _service.loadSettings();
    _refresh();
  }

  Future<void> setBlfEnabled(bool value) async {
    await _service.setBlfEnabled(value);
    _refresh();
  }

  Future<void> setDndEnabled(bool value) async {
    await _service.setDndEnabled(value);
    _refresh();
  }

  Future<void> setAutoAnswer(bool value) async {
    await _service.setAutoAnswer(value);
    _refresh();
  }

  Future<void> setDtmfMethod(int method) async {
    await _service.setDtmfMethod(method);
    _refresh();
  }

  Future<void> setCodecPriorities(List<Map<String, dynamic>> priorities) async {
    await _service.setCodecPriorities(priorities);
    _refresh();
  }

  Future<void> resetToDefaults() async {
    await _service.setCodecPriorities([
      {'codec': 'PCMU', 'priority': 10, 'enabled': true},
      {'codec': 'PCMA', 'priority': 9, 'enabled': true},
      {'codec': 'G729', 'priority': 8, 'enabled': true},
    ]);
    await _service.setDtmfMethod(1);
    await _service.setAutoAnswer(false);
    await _service.setBlfEnabled(true);
    _refresh();
  }
}

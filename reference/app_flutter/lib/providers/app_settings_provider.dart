import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_settings_service.dart';
import '../core/engine_channel.dart';

class AppSettingsData {
  final List<Map<String, dynamic>> codecPriorities;
  final int dtmfMethod;
  final bool ecEnabled;
  final bool micAmplificationEnabled;
  final bool autoAnswerEnabled;
  final bool dndEnabled;
  final bool blfEnabled;
  final bool startWithWindowsEnabled;
  final bool localCallRecordingEnabled;
  final String localRecordingDirectory;
  final bool lightModeEnabled;

  AppSettingsData({
    required this.codecPriorities,
    required this.dtmfMethod,
    required this.ecEnabled,
    required this.micAmplificationEnabled,
    required this.autoAnswerEnabled,
    required this.dndEnabled,
    required this.blfEnabled,
    required this.startWithWindowsEnabled,
    required this.localCallRecordingEnabled,
    required this.localRecordingDirectory,
    required this.lightModeEnabled,
  });

  factory AppSettingsData.defaultSettings() {
    return AppSettingsData(
      codecPriorities: const [],
      dtmfMethod: 3,
      ecEnabled: true,
      micAmplificationEnabled: false,
      autoAnswerEnabled: false,
      dndEnabled: false,
      blfEnabled: true,
      startWithWindowsEnabled: false,
      localCallRecordingEnabled: false,
      localRecordingDirectory: '',
      lightModeEnabled: false,
    );
  }

  factory AppSettingsData.fromService(AppSettingsService service) {
    return AppSettingsData(
      codecPriorities: service.codecPriorities,
      dtmfMethod: service.dtmfMethod,
      ecEnabled: service.ecEnabled,
      micAmplificationEnabled: service.micAmplificationEnabled,
      autoAnswerEnabled: service.autoAnswerEnabled,
      dndEnabled: service.dndEnabled,
      blfEnabled: service.blfEnabled,
      startWithWindowsEnabled: service.startWithWindowsEnabled,
      localCallRecordingEnabled: service.localCallRecordingEnabled,
      localRecordingDirectory: service.localRecordingDirectory,
      lightModeEnabled: service.lightModeEnabled,
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

  Future<void> setLightModeEnabled(bool value) async {
    await _service.setLightModeEnabled(value);
    _refresh();
  }

  Future<void> setStartWithWindowsEnabled(bool value) async {
    await _service.setStartWithWindowsEnabled(value);
    _refresh();
  }

  Future<void> setGlobalDndEnabled(bool value) async {
    await _service.setGlobalDndEnabled(value);
    final rc = EngineChannel.instance.engine
        .sendCommand('SetGlobalDnd', '{"enabled":$value}');
    if (rc != 0) {
      throw Exception('Failed to apply global DND in engine (rc=$rc)');
    }
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

  Future<void> setEcEnabled(bool value) async {
    await _service.setEcEnabled(value);
    EngineChannel.instance.engine
        .sendCommand('SetEcEnabled', '{"enabled":$value}');
    _refresh();
  }

  Future<void> setMicAmplificationEnabled(bool value) async {
    await _service.setMicAmplificationEnabled(value);
    final level = _service.micAmplificationLevel;
    EngineChannel.instance.engine
        .sendCommand('SetMicAmplification', '{"level":$level}');
    _refresh();
  }

  Future<void> setCodecPriorities(List<Map<String, dynamic>> priorities) async {
    await _service.setCodecPriorities(priorities);
    _refresh();
  }

  Future<void> setLocalCallRecordingEnabled(bool value) async {
    await _service.setLocalCallRecordingEnabled(value);
    _refresh();
  }

  Future<void> setLocalRecordingDirectory(String value) async {
    await _service.setLocalRecordingDirectory(value);
    _refresh();
  }

  Future<void> resetToDefaults() async {
    await _service.setCodecPriorities([
      {'codec': 'PCMU', 'priority': 10, 'enabled': true},
      {'codec': 'PCMA', 'priority': 9, 'enabled': true},
      {'codec': 'G729', 'priority': 8, 'enabled': true},
    ]);
    await _service.setDtmfMethod(3);
    await _service.setEcEnabled(true);
    await _service.setMicAmplificationEnabled(false);
    await _service.setAutoAnswer(false);
    await _service.setBlfEnabled(true);
    await _service.setStartWithWindowsEnabled(false);
    _refresh();
  }
}

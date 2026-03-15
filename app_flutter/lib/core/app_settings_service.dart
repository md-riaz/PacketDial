import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'path_provider_service.dart';
import '../models/dialing_rule.dart';
import '../models/caller_id_transformation.dart';

/// App-wide settings with file-based persistence.
class AppSettingsService {
  AppSettingsService._();
  static final AppSettingsService instance = AppSettingsService._();
  static const String _windowsRunKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _windowsRunValueName = 'PacketDial';
  static const String _windowsAutoStartArg = '--startup-launch';

  // Codec settings
  List<Map<String, dynamic>> _codecPriorities = [];

  // DTMF settings
  int _dtmfMethod = 1; // 0=In-band, 1=RFC2833 (default), 2=SIP INFO

  // Auto Answer settings
  bool _autoAnswerEnabled = false;

  // DND settings (app-wide)
  bool _dndEnabled = false;

  // BLF settings
  bool _blfEnabled = true;
  bool _startWithWindowsEnabled = false;

  // Integration settings - Webhooks
  String _ringWebhookUrl = '';
  bool _ringWebhookEnabled = false;
  String _endWebhookUrl = '';
  bool _callEndWebhookEnabled = true;

  // Integration settings - Customer Lookup
  String _customerLookupUrl = '';
  int _customerLookupTimeoutMs = 5000;
  bool _customerLookupEnabled = false;

  // Integration settings - Screen Pop
  String _screenPopUrl = '';
  String _screenPopEvent = 'ring'; // 'ring' or 'answer'
  bool _screenPopOpenBrowser = true;
  bool _screenPopSuppressWindow = false;

  // Integration settings - Recording Upload
  bool _localCallRecordingEnabled = false;
  String _localRecordingDirectory = '';
  String _localRecordingFormat = 'wav';
  String _recordingUploadUrl = '';
  String _recordingFileFieldName = 'recording';
  bool _recordingUploadEnabled = false;

  // Dialing Rules
  List<DialingRule> _dialingRules = [];

  // Caller ID Transformations
  List<CallerIdTransformation> _callerIdTransformations = [];

  bool _isLoaded = false;

  // Getters - Core SIP
  List<Map<String, dynamic>> get codecPriorities =>
      List.unmodifiable(_codecPriorities);
  int get dtmfMethod => _dtmfMethod;
  bool get autoAnswerEnabled => _autoAnswerEnabled;
  bool get dndEnabled => _dndEnabled;
  bool get blfEnabled => _blfEnabled;
  bool get startWithWindowsEnabled => _startWithWindowsEnabled;

  // Getters - Webhooks
  String get ringWebhookUrl => _ringWebhookUrl;
  bool get ringWebhookEnabled => _ringWebhookEnabled;
  String get endWebhookUrl => _endWebhookUrl;
  bool get callEndWebhookEnabled => _callEndWebhookEnabled;

  // Getters - Customer Lookup
  String get customerLookupUrl => _customerLookupUrl;
  int get customerLookupTimeoutMs => _customerLookupTimeoutMs;
  bool get customerLookupEnabled => _customerLookupEnabled;

  // Getters - Screen Pop
  String get screenPopUrl => _screenPopUrl;
  String get screenPopEvent => _screenPopEvent;
  bool get screenPopOpenBrowser => _screenPopOpenBrowser;
  bool get screenPopSuppressWindow => _screenPopSuppressWindow;

  // Getters - Recording Upload
  bool get localCallRecordingEnabled => _localCallRecordingEnabled;
  String get localRecordingDirectory => _localRecordingDirectory;
  String get localRecordingFormat => _localRecordingFormat;
  String get recordingUploadUrl => _recordingUploadUrl;
  String get recordingFileFieldName => _recordingFileFieldName;
  bool get recordingUploadEnabled => _recordingUploadEnabled;

  // Getters - Dialing Rules
  List<DialingRule> get dialingRules => List.unmodifiable(_dialingRules);

  // Getters - Caller ID Transformations
  List<CallerIdTransformation> get callerIdTransformations =>
      List.unmodifiable(_callerIdTransformations);

  /// Load settings from file on app startup.
  Future<void> loadSettings() async {
    if (_isLoaded) return;

    bool shouldEnableDefaultAutoStart = false;

    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;

        _codecPriorities = List<Map<String, dynamic>>.from(
          data['codec_priorities'] as List? ?? [],
        );
        _dtmfMethod = data['dtmf_method'] as int? ?? 1;
        _autoAnswerEnabled = data['auto_answer_enabled'] as bool? ?? false;
        _dndEnabled = data['dnd_enabled'] as bool? ?? false;
        _blfEnabled = data['blf_enabled'] as bool? ?? true;
        _startWithWindowsEnabled =
            data['start_with_windows_enabled'] as bool? ?? true;
        _ringWebhookUrl = data['ring_webhook_url'] as String? ?? '';
        _ringWebhookEnabled =
            data['ring_webhook_enabled'] as bool? ?? _ringWebhookUrl.isNotEmpty;
        _endWebhookUrl = data['end_webhook_url'] as String? ?? '';
        _callEndWebhookEnabled =
            data['call_end_webhook_enabled'] as bool? ?? true;
        _customerLookupUrl = data['customer_lookup_url'] as String? ?? '';
        _customerLookupTimeoutMs =
            data['customer_lookup_timeout_ms'] as int? ?? 5000;
        _customerLookupEnabled =
            data['customer_lookup_enabled'] as bool? ?? false;
        _screenPopUrl = data['screen_pop_url'] as String? ?? '';
        _screenPopEvent = data['screen_pop_event'] as String? ?? 'ring';
        _screenPopOpenBrowser =
            data['screen_pop_open_browser'] as bool? ?? true;
        _screenPopSuppressWindow =
            data['screen_pop_suppress_window'] as bool? ?? false;
        _localCallRecordingEnabled =
            data['local_call_recording_enabled'] as bool? ?? false;
        _localRecordingDirectory =
            data['local_recording_directory'] as String? ?? '';
        final storedRecordingFormat =
            data['local_recording_format'] as String? ?? 'wav';
        _localRecordingFormat =
            storedRecordingFormat.toLowerCase() == 'wav' ? 'wav' : 'wav';
        _recordingUploadUrl = data['recording_upload_url'] as String? ?? '';
        _recordingFileFieldName =
            data['recording_file_field_name'] as String? ?? 'recording';
        _recordingUploadEnabled =
            data['recording_upload_enabled'] as bool? ?? false;

        // Load dialing rules
        final dialingRulesJson = data['dialing_rules'] as List? ?? [];
        _dialingRules = dialingRulesJson
            .map((r) => DialingRule.fromJson(r as Map<String, dynamic>))
            .toList();

        // Load caller ID transformations
        final transformationsJson =
            data['caller_id_transformations'] as List? ?? [];
        _callerIdTransformations = transformationsJson
            .map((t) =>
                CallerIdTransformation.fromJson(t as Map<String, dynamic>))
            .toList();

        shouldEnableDefaultAutoStart =
            !data.containsKey('start_with_windows_enabled');
        debugPrint('[AppSettings] Loaded settings from file');
      } else {
        // Initialize with default codec list
        _codecPriorities = [
          {'codec': 'PCMU', 'priority': 10, 'enabled': true},
          {'codec': 'PCMA', 'priority': 9, 'enabled': true},
          {'codec': 'G729', 'priority': 8, 'enabled': true},
          {'codec': 'G722', 'priority': 7, 'enabled': true},
          {'codec': 'OPUS', 'priority': 6, 'enabled': true},
        ];
        _startWithWindowsEnabled = true;
        shouldEnableDefaultAutoStart = true;
        debugPrint('[AppSettings] Initialized with defaults');
        // Save defaults immediately so the user can see/edit the file
        await saveSettings();
      }
    } catch (e) {
      debugPrint('[AppSettings] Error loading settings: $e');
      // Use defaults on error
      _codecPriorities = [
        {'codec': 'PCMU', 'priority': 10, 'enabled': true},
        {'codec': 'PCMA', 'priority': 9, 'enabled': true},
      ];
      _startWithWindowsEnabled = true;
    }

    if (shouldEnableDefaultAutoStart) {
      try {
        await _setWindowsAutoStartEnabled(true);
      } catch (e) {
        debugPrint(
            '[AppSettings] Error enabling default Windows auto-start: $e');
      }
    }

    _startWithWindowsEnabled = await _isWindowsAutoStartEnabled();
    if (_startWithWindowsEnabled) {
      try {
        await _syncWindowsAutoStartRegistration();
      } catch (e) {
        debugPrint('[AppSettings] Error syncing Windows auto-start: $e');
      }
    }

    _isLoaded = true;
  }

  /// Save settings to file.
  Future<void> saveSettings() async {
    try {
      final file = await _getSettingsFile();
      final data = {
        'codec_priorities': _codecPriorities,
        'dtmf_method': _dtmfMethod,
        'auto_answer_enabled': _autoAnswerEnabled,
        'dnd_enabled': _dndEnabled,
        'blf_enabled': _blfEnabled,
        'start_with_windows_enabled': _startWithWindowsEnabled,
        'ring_webhook_url': _ringWebhookUrl,
        'ring_webhook_enabled': _ringWebhookEnabled,
        'end_webhook_url': _endWebhookUrl,
        'call_end_webhook_enabled': _callEndWebhookEnabled,
        'customer_lookup_url': _customerLookupUrl,
        'customer_lookup_timeout_ms': _customerLookupTimeoutMs,
        'customer_lookup_enabled': _customerLookupEnabled,
        'screen_pop_url': _screenPopUrl,
        'screen_pop_event': _screenPopEvent,
        'screen_pop_open_browser': _screenPopOpenBrowser,
        'screen_pop_suppress_window': _screenPopSuppressWindow,
        'local_call_recording_enabled': _localCallRecordingEnabled,
        'local_recording_directory': _localRecordingDirectory,
        'local_recording_format': _localRecordingFormat,
        'recording_upload_url': _recordingUploadUrl,
        'recording_file_field_name': _recordingFileFieldName,
        'recording_upload_enabled': _recordingUploadEnabled,
        'dialing_rules': _dialingRules.map((r) => r.toJson()).toList(),
        'caller_id_transformations':
            _callerIdTransformations.map((t) => t.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
      debugPrint('[AppSettings] Saved settings to file');
    } catch (e) {
      debugPrint('[AppSettings] Error saving settings: $e');
    }
  }

  /// Update codec priorities.
  Future<void> setCodecPriorities(List<Map<String, dynamic>> priorities) async {
    _codecPriorities = priorities;
    await saveSettings();
  }

  /// Update DTMF method.
  Future<void> setDtmfMethod(int method) async {
    _dtmfMethod = method;
    await saveSettings();
  }

  /// Update auto-answer.
  Future<void> setAutoAnswer(bool enabled) async {
    _autoAnswerEnabled = enabled;
    await saveSettings();
  }

  /// Update global DND.
  Future<void> setGlobalDndEnabled(bool enabled) async {
    _dndEnabled = enabled;
    await saveSettings();
  }

  /// Update BLF enabled.
  Future<void> setBlfEnabled(bool enabled) async {
    _blfEnabled = enabled;
    await saveSettings();
  }

  Future<void> setStartWithWindowsEnabled(bool enabled) async {
    await _setWindowsAutoStartEnabled(enabled);
    _startWithWindowsEnabled = await _isWindowsAutoStartEnabled();
    await saveSettings();
  }

  Future<void> setRingWebhookUrl(String url) async {
    _ringWebhookUrl = url;
    await saveSettings();
  }

  Future<void> setRingWebhookEnabled(bool enabled) async {
    _ringWebhookEnabled = enabled;
    await saveSettings();
  }

  Future<void> setEndWebhookUrl(String url) async {
    _endWebhookUrl = url;
    await saveSettings();
  }

  Future<void> setCallEndWebhookEnabled(bool enabled) async {
    _callEndWebhookEnabled = enabled;
    await saveSettings();
  }

  Future<void> setCustomerLookupUrl(String url) async {
    _customerLookupUrl = url;
    await saveSettings();
  }

  Future<void> setCustomerLookupTimeoutMs(int ms) async {
    _customerLookupTimeoutMs = ms;
    await saveSettings();
  }

  Future<void> setCustomerLookupEnabled(bool enabled) async {
    _customerLookupEnabled = enabled;
    await saveSettings();
  }

  Future<void> setScreenPopUrl(String url) async {
    _screenPopUrl = url;
    await saveSettings();
  }

  Future<void> setScreenPopEvent(String event) async {
    _screenPopEvent = event;
    await saveSettings();
  }

  Future<void> setScreenPopOpenBrowser(bool openBrowser) async {
    _screenPopOpenBrowser = openBrowser;
    await saveSettings();
  }

  Future<void> setScreenPopSuppressWindow(bool suppress) async {
    _screenPopSuppressWindow = suppress;
    await saveSettings();
  }

  Future<void> setRecordingUploadUrl(String url) async {
    _recordingUploadUrl = url;
    await saveSettings();
  }

  Future<void> setLocalCallRecordingEnabled(bool enabled) async {
    _localCallRecordingEnabled = enabled;
    await saveSettings();
  }

  Future<void> setLocalRecordingDirectory(String directory) async {
    _localRecordingDirectory = directory;
    await saveSettings();
  }

  Future<void> setLocalRecordingFormat(String format) async {
    _localRecordingFormat = 'wav';
    await saveSettings();
  }

  Future<void> setRecordingFileFieldName(String name) async {
    _recordingFileFieldName = name;
    await saveSettings();
  }

  Future<void> setRecordingUploadEnabled(bool enabled) async {
    _recordingUploadEnabled = enabled;
    await saveSettings();
  }

  // Dialing Rules methods
  Future<void> addDialingRule(DialingRule rule) async {
    _dialingRules.add(rule);
    _dialingRules.sort((a, b) => b.priority.compareTo(a.priority));
    await saveSettings();
  }

  Future<void> removeDialingRule(String id) async {
    _dialingRules.removeWhere((r) => r.id == id);
    await saveSettings();
  }

  Future<void> updateDialingRule(DialingRule rule) async {
    final index = _dialingRules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      _dialingRules[index] = rule;
      _dialingRules.sort((a, b) => b.priority.compareTo(a.priority));
      await saveSettings();
    }
  }

  Future<void> reorderDialingRules(List<DialingRule> orderedRules) async {
    _dialingRules = orderedRules;
    await saveSettings();
  }

  // Caller ID Transformations methods
  Future<void> addCallerIdTransformation(
      CallerIdTransformation transformation) async {
    _callerIdTransformations.add(transformation);
    _callerIdTransformations.sort((a, b) => b.priority.compareTo(a.priority));
    await saveSettings();
  }

  Future<void> removeCallerIdTransformation(String id) async {
    _callerIdTransformations.removeWhere((t) => t.id == id);
    await saveSettings();
  }

  Future<void> updateCallerIdTransformation(
      CallerIdTransformation transformation) async {
    final index =
        _callerIdTransformations.indexWhere((t) => t.id == transformation.id);
    if (index >= 0) {
      _callerIdTransformations[index] = transformation;
      _callerIdTransformations.sort((a, b) => b.priority.compareTo(a.priority));
      await saveSettings();
    }
  }

  /// Transform a phone number using dialing rules
  String transformNumber(String number) {
    String result = number;
    for (final rule in _dialingRules.where((r) => r.enabled)) {
      final transformed = rule.apply(result);
      if (transformed != null) {
        result = transformed;
      }
    }
    return result;
  }

  /// Transform a caller ID using transformation rules
  String transformCallerId(String callerId) {
    String result = callerId;
    for (final transformation
        in _callerIdTransformations.where((t) => t.enabled)) {
      final transformed = transformation.apply(result);
      if (transformed != null) {
        result = transformed;
      }
    }
    return result;
  }

  /// Get settings file path.
  Future<File> _getSettingsFile() async {
    final dir = await PathProviderService.instance.getDataDirectory();
    return File('${dir.path}/app_settings.json');
  }

  Future<bool> _isWindowsAutoStartEnabled() async {
    if (!Platform.isWindows) return false;

    try {
      final result = await Process.run('reg', [
        'query',
        _windowsRunKey,
        '/v',
        _windowsRunValueName,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[AppSettings] Error checking Windows auto-start: $e');
      return false;
    }
  }

  Future<void> _setWindowsAutoStartEnabled(bool enabled) async {
    if (!Platform.isWindows) {
      _startWithWindowsEnabled = false;
      return;
    }

    try {
      if (enabled) {
        final executablePath = Platform.resolvedExecutable;
        final valueData = '"$executablePath" $_windowsAutoStartArg';
        final result = await Process.run('reg', [
          'add',
          _windowsRunKey,
          '/v',
          _windowsRunValueName,
          '/t',
          'REG_SZ',
          '/d',
          valueData,
          '/f',
        ]);
        if (result.exitCode != 0) {
          throw Exception(result.stderr.toString().trim());
        }
      } else {
        await Process.run('reg', [
          'delete',
          _windowsRunKey,
          '/v',
          _windowsRunValueName,
          '/f',
        ]);
      }
    } catch (e) {
      debugPrint('[AppSettings] Error updating Windows auto-start: $e');
      rethrow;
    }
  }

  Future<void> _syncWindowsAutoStartRegistration() async {
    if (!Platform.isWindows) return;
    await _setWindowsAutoStartEnabled(true);
  }

  /// Export settings to file.
  Future<bool> exportSettings(File file) async {
    try {
      final data = {
        'codec_priorities': _codecPriorities,
        'dtmf_method': _dtmfMethod,
        'auto_answer_enabled': _autoAnswerEnabled,
        'blf_enabled': _blfEnabled,
        'start_with_windows_enabled': _startWithWindowsEnabled,
      };
      await file.writeAsString(jsonEncode(data));
      return true;
    } catch (e) {
      debugPrint('[AppSettings] Export error: $e');
      return false;
    }
  }

  /// Import settings from file.
  Future<bool> importSettings(File file) async {
    try {
      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (data.containsKey('codec_priorities')) {
        _codecPriorities = List<Map<String, dynamic>>.from(
          data['codec_priorities'] as List,
        );
      }
      if (data.containsKey('dtmf_method')) {
        _dtmfMethod = data['dtmf_method'] as int;
      }
      if (data.containsKey('auto_answer_enabled')) {
        _autoAnswerEnabled = data['auto_answer_enabled'] as bool;
      }
      if (data.containsKey('blf_enabled')) {
        _blfEnabled = data['blf_enabled'] as bool;
      }
      if (data.containsKey('start_with_windows_enabled')) {
        await setStartWithWindowsEnabled(
          data['start_with_windows_enabled'] as bool,
        );
      }

      await saveSettings();
      return true;
    } catch (e) {
      debugPrint('[AppSettings] Import error: $e');
      return false;
    }
  }

  /// Clear customer lookup cache (called from UI)
  void clearCustomerLookupCache() {
    // This is just a stub - actual cache is in CustomerLookupService
    debugPrint('[AppSettings] Customer lookup cache clear requested');
  }
}

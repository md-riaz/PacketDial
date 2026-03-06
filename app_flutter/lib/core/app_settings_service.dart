import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// App-wide settings with file-based persistence.
class AppSettingsService {
  AppSettingsService._();
  static final AppSettingsService instance = AppSettingsService._();

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
  
  bool _isLoaded = false;

  // Getters
  List<Map<String, dynamic>> get codecPriorities => List.unmodifiable(_codecPriorities);
  int get dtmfMethod => _dtmfMethod;
  bool get autoAnswerEnabled => _autoAnswerEnabled;
  bool get dndEnabled => _dndEnabled;
  bool get blfEnabled => _blfEnabled;

  /// Load settings from file on app startup.
  Future<void> loadSettings() async {
    if (_isLoaded) return;

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
        
        debugPrint('[AppSettings] Loaded settings from file');
      } else {
        // Initialize with defaults
        _codecPriorities = [
          {'codec': 'PCMU', 'priority': 10, 'enabled': true},
          {'codec': 'PCMA', 'priority': 9, 'enabled': true},
          {'codec': 'G729', 'priority': 8, 'enabled': true},
          {'codec': 'G722', 'priority': 7, 'enabled': true},
          {'codec': 'OPUS', 'priority': 6, 'enabled': true},
        ];
        debugPrint('[AppSettings] Initialized with defaults');
      }
    } catch (e) {
      debugPrint('[AppSettings] Error loading settings: $e');
      // Use defaults on error
      _codecPriorities = [
        {'codec': 'PCMU', 'priority': 10, 'enabled': true},
        {'codec': 'PCMA', 'priority': 9, 'enabled': true},
      ];
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

  /// Update DND.
  Future<void> setDndEnabled(bool enabled) async {
    _dndEnabled = enabled;
    await saveSettings();
  }

  /// Update BLF enabled.
  Future<void> setBlfEnabled(bool enabled) async {
    _blfEnabled = enabled;
    await saveSettings();
  }

  /// Get settings file path.
  Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_settings.json');
  }

  /// Export settings to file.
  Future<bool> exportSettings(File file) async {
    try {
      final data = {
        'codec_priorities': _codecPriorities,
        'dtmf_method': _dtmfMethod,
        'auto_answer_enabled': _autoAnswerEnabled,
        'blf_enabled': _blfEnabled,
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
      
      await saveSettings();
      return true;
    } catch (e) {
      debugPrint('[AppSettings] Import error: $e');
      return false;
    }
  }
}

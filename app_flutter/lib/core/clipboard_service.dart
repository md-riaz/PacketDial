import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dialing_rules_service.dart';
import 'app_settings_service.dart';

/// Service for monitoring clipboard for phone numbers
class ClipboardService {
  ClipboardService._();
  static final ClipboardService instance = ClipboardService._();

  Timer? _clipboardTimer;
  String? _lastClipboardContent;
  final _dialingRules = DialingRulesService.instance;
  
  final _phoneDetectedController = StreamController<String>.broadcast();
  Stream<String> get onPhoneDetected => _phoneDetectedController.stream;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  /// Initialize the service (called from main.dart)
  void init() {
    if (AppSettingsService.instance.clipboardMonitoringEnabled) {
      startMonitoring();
    }
  }

  /// Start monitoring clipboard for phone numbers
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    final pollInterval = AppSettingsService.instance.clipboardPollIntervalMs;
    
    debugPrint('[Clipboard] Starting monitoring (interval: ${pollInterval}ms)');

    _clipboardTimer = Timer.periodic(
      Duration(milliseconds: pollInterval),
      _checkClipboard,
    );
  }

  /// Stop monitoring clipboard
  void stopMonitoring() {
    _clipboardTimer?.cancel();
    _clipboardTimer = null;
    _lastClipboardContent = null;
    _isMonitoring = false;
    
    debugPrint('[Clipboard] Stopped monitoring');
  }

  /// Check clipboard for new phone numbers
  void _checkClipboard(Timer timer) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final content = clipboardData?.text?.trim() ?? '';
      
      // Skip if content is empty or same as last check
      if (content.isEmpty || content == _lastClipboardContent) {
        return;
      }
      
      _lastClipboardContent = content;
      
      // Check if content contains a phone number
      final phoneNumbers = _dialingRules.extractPhoneNumbers(content);
      
      if (phoneNumbers.isNotEmpty) {
        debugPrint('[Clipboard] Found phone number(s): $phoneNumbers');
        // Emit the first detected phone number
        _phoneDetectedController.add(phoneNumbers.first);
      }
    } catch (e) {
      debugPrint('[Clipboard] Error checking clipboard: $e');
    }
  }

  /// Get current clipboard content
  Future<String?> getCurrentContent() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      return clipboardData?.text?.trim();
    } catch (e) {
      debugPrint('[Clipboard] Error getting content: $e');
      return null;
    }
  }

  /// Check if current clipboard content is a phone number
  Future<bool> hasPhoneNumber() async {
    final content = await getCurrentContent();
    if (content == null || content.isEmpty) return false;
    return _dialingRules.isValidPhoneNumber(content);
  }

  /// Get phone number from current clipboard content
  Future<String?> getPhoneNumber() async {
    final content = await getCurrentContent();
    if (content == null || content.isEmpty) return null;
    
    final phoneNumbers = _dialingRules.extractPhoneNumbers(content);
    return phoneNumbers.isNotEmpty ? phoneNumbers.first : null;
  }

  /// Update monitoring interval (requires restart)
  Future<void> updateInterval(int milliseconds) async {
    final wasMonitoring = _isMonitoring;
    if (wasMonitoring) {
      stopMonitoring();
    }
    
    await AppSettingsService.instance.setClipboardPollIntervalMs(milliseconds);
    
    if (wasMonitoring) {
      startMonitoring();
    }
  }

  /// Dispose of resources
  void dispose() {
    stopMonitoring();
    _phoneDetectedController.close();
  }
}

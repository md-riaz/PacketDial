import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'engine_channel.dart';
import 'integration_service.dart';

/// Service for managing call recordings
class RecordingService {
  RecordingService._();
  static final RecordingService instance = RecordingService._();

  String? _currentRecordingPath;
  bool _isRecording = false;

  /// Get the default recordings directory
  Future<Directory> getRecordingsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(appDir.path, 'recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  /// Generate a recording file path
  Future<String> generateRecordingPath() async {
    final dir = await getRecordingsDir();
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    return p.join(dir.path, 'call_$timestamp.wav');
  }

  /// Start recording the current call
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('[RecordingService] Already recording');
      return false;
    }

    try {
      _currentRecordingPath = await generateRecordingPath();
      debugPrint('[RecordingService] Starting recording: $_currentRecordingPath');

      final result = EngineChannel.instance.engine.startRecording(_currentRecordingPath!);

      if (result == 0) {
        _isRecording = true;
        debugPrint('[RecordingService] Recording started successfully');
        return true;
      } else {
        debugPrint('[RecordingService] Failed to start recording: $result');
        _currentRecordingPath = null;
        return false;
      }
    } catch (e) {
      debugPrint('[RecordingService] Error starting recording: $e');
      _currentRecordingPath = null;
      return false;
    }
  }

  /// Stop recording the current call and trigger upload
  Future<bool> stopRecording() async {
    if (!_isRecording) {
      debugPrint('[RecordingService] Not recording');
      return false;
    }

    try {
      final result = EngineChannel.instance.engine.stopRecording();
      final path = _currentRecordingPath;
      _isRecording = false;
      _currentRecordingPath = null;

      if (result == 0) {
        debugPrint('[RecordingService] Recording stopped: $path');

        // Trigger upload if configured
        final activeCall = EngineChannel.instance.activeCall;
        if (path != null && activeCall != null) {
          await IntegrationService.instance.onCallEnd(
            activeCall,
            recordingPath: path,
          );
        }

        return true;
      } else {
        debugPrint('[RecordingService] Failed to stop recording: $result');
        return false;
      }
    } catch (e) {
      debugPrint('[RecordingService] Error stopping recording: $e');
      return false;
    }
  }

  /// Toggle recording
  Future<bool> toggleRecording() async {
    if (_isRecording) {
      return await stopRecording();
    } else {
      return await startRecording();
    }
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get current recording path
  String? get currentRecordingPath => _currentRecordingPath;

  /// Get list of all recordings
  Future<List<File>> getRecordings() async {
    try {
      final dir = await getRecordingsDir();
      final files = await dir.list().toList();
      return files
          .whereType<File>()
          .where((f) => f.path.endsWith('.wav'))
          .toList();
    } catch (e) {
      debugPrint('[RecordingService] Error getting recordings: $e');
      return [];
    }
  }

  /// Delete a recording
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[RecordingService] Deleted recording: $path');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[RecordingService] Error deleting recording: $e');
      return false;
    }
  }

  /// Reset state (call ended) - also triggers upload if recording was active
  void reset() {
    if (_isRecording && _currentRecordingPath != null) {
      // Recording was active when call ended - trigger upload
      final path = _currentRecordingPath;
      final activeCall = EngineChannel.instance.activeCall;
      _isRecording = false;
      _currentRecordingPath = null;

      if (path != null && activeCall != null) {
        debugPrint('[RecordingService] Call ended, triggering upload for: $path');
        // Fire and forget - don't await
        IntegrationService.instance.onCallEnd(
          activeCall,
          recordingPath: path,
        );
      }
    } else {
      _isRecording = false;
      _currentRecordingPath = null;
    }
  }
}

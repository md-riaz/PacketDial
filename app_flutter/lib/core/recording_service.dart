import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/call.dart';
import 'app_settings_service.dart';
import 'engine_channel.dart';
import 'path_provider_service.dart';

const _kEngineMediaNotReady = 7;
const _kRecordingStartRetryDelay = Duration(milliseconds: 350);

enum RecordingPhase {
  idle,
  starting,
  recording,
  stopping,
  stopped,
  failed,
}

class RecordingSession {
  const RecordingSession({
    required this.callId,
    required this.filePath,
    required this.phase,
    this.startedAt,
    this.endedAt,
    this.durationMs,
    this.errorCode,
    this.errorMessage,
    this.autoRequested = false,
  });

  final int callId;
  final String? filePath;
  final RecordingPhase phase;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationMs;
  final String? errorCode;
  final String? errorMessage;
  final bool autoRequested;

  bool get isActive =>
      phase == RecordingPhase.starting || phase == RecordingPhase.recording;

  RecordingSession copyWith({
    String? filePath,
    bool clearFilePath = false,
    RecordingPhase? phase,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? endedAt,
    bool clearEndedAt = false,
    int? durationMs,
    bool clearDurationMs = false,
    String? errorCode,
    bool clearErrorCode = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? autoRequested,
  }) {
    return RecordingSession(
      callId: callId,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      phase: phase ?? this.phase,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      durationMs: clearDurationMs ? null : (durationMs ?? this.durationMs),
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      autoRequested: autoRequested ?? this.autoRequested,
    );
  }
}

/// Per-call recording controller backed by the native engine.
class RecordingService extends ChangeNotifier {
  RecordingService._();

  static final RecordingService instance = RecordingService._();

  final Map<int, RecordingSession> _sessions = <int, RecordingSession>{};
  final Set<int> _pendingAutoStart = <int>{};

  RecordingSession? sessionForCall(int callId) => _sessions[callId];

  bool isRecordingForCall(int callId) =>
      _sessions[callId]?.phase == RecordingPhase.recording;

  bool isBusyForCall(int callId) {
    final phase = _sessions[callId]?.phase;
    return phase == RecordingPhase.starting || phase == RecordingPhase.stopping;
  }

  bool get isRecording =>
      _sessions.values.any((session) => session.phase == RecordingPhase.recording);

  String? get currentRecordingPath {
    for (final session in _sessions.values) {
      if (session.filePath != null && session.isActive) {
        return session.filePath;
      }
    }
    return null;
  }

  String? recordingPathForCall(int callId) => _sessions[callId]?.filePath;

  Future<Directory> getRecordingsDir() async {
    final configuredDir = AppSettingsService.instance.localRecordingDirectory;
    final dirPath = configuredDir.trim().isNotEmpty
        ? configuredDir.trim()
        : await _defaultRecordingsDirPath();
    final recordingsDir = Directory(dirPath);
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  Future<String> generateRecordingPath(int callId, {DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    final rootDir = await getRecordingsDir();
    final yearDir = timestamp.year.toString().padLeft(4, '0');
    final monthDir = timestamp.month.toString().padLeft(2, '0');
    final targetDir = Directory(p.join(rootDir.path, yearDir, monthDir));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final fileName =
        '${callId}_${_formatCompactTimestamp(timestamp.toUtc())}.wav';
    return p.join(targetDir.path, fileName);
  }

  Future<bool> startRecordingForCall(
    int callId, {
    bool autoRequested = false,
    int retryCount = 0,
  }) async {
    final existing = _sessions[callId];
    if (existing != null && existing.isActive) {
      return true;
    }

    final filePath = existing != null &&
            existing.phase == RecordingPhase.starting &&
            existing.filePath != null
        ? existing.filePath!
        : await generateRecordingPath(callId);
    _sessions[callId] = RecordingSession(
      callId: callId,
      filePath: filePath,
      phase: RecordingPhase.starting,
      autoRequested: autoRequested || (existing?.autoRequested ?? false),
    );
    notifyListeners();

    try {
      final result = EngineChannel.instance.engine.startRecordingForCall(
        callId,
        filePath,
      );
      if (result == 0) {
        return true;
      }

      if (result == _kEngineMediaNotReady && retryCount < 5) {
        await Future<void>.delayed(_kRecordingStartRetryDelay);
        return startRecordingForCall(
          callId,
          autoRequested: autoRequested,
          retryCount: retryCount + 1,
        );
      }

      _sessions[callId] = _sessions[callId]!.copyWith(
        phase: RecordingPhase.failed,
        errorCode: 'EngineError',
        errorMessage: 'Failed to start recording (code $result)',
      );
      notifyListeners();
      return false;
    } catch (e) {
      _sessions[callId] = _sessions[callId]!.copyWith(
        phase: RecordingPhase.failed,
        errorCode: 'Exception',
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> stopRecordingForCall(int callId) async {
    final existing = _sessions[callId];
    if (existing == null || !existing.isActive) {
      return false;
    }

    _sessions[callId] = existing.copyWith(phase: RecordingPhase.stopping);
    notifyListeners();

    try {
      final result = EngineChannel.instance.engine.stopRecordingForCall(callId);
      if (result == 0) {
        return true;
      }
      _sessions[callId] = _sessions[callId]!.copyWith(
        phase: RecordingPhase.failed,
        errorCode: 'EngineError',
        errorMessage: 'Failed to stop recording (code $result)',
      );
      notifyListeners();
      return false;
    } catch (e) {
      _sessions[callId] = _sessions[callId]!.copyWith(
        phase: RecordingPhase.failed,
        errorCode: 'Exception',
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleRecordingForCall(int callId) async {
    if (isRecordingForCall(callId)) {
      return stopRecordingForCall(callId);
    }
    return startRecordingForCall(callId);
  }

  Future<void> maybeAutoStartForCall(ActiveCall call) async {
    if (!AppSettingsService.instance.localCallRecordingEnabled) {
      _pendingAutoStart.remove(call.callId);
      return;
    }
    if (call.state != CallState.inCall) {
      return;
    }
    final existing = _sessions[call.callId];
    if (existing != null &&
        (existing.phase == RecordingPhase.starting ||
            existing.phase == RecordingPhase.recording ||
            existing.phase == RecordingPhase.stopping)) {
      return;
    }
    if (_pendingAutoStart.contains(call.callId)) {
      return;
    }

    _pendingAutoStart.add(call.callId);
    try {
      await startRecordingForCall(call.callId, autoRequested: true);
    } finally {
      _pendingAutoStart.remove(call.callId);
    }
  }

  void handleRecordingStarted(Map<String, dynamic> payload) {
    final callId = (payload['call_id'] as num?)?.toInt();
    if (callId == null) return;
    final startedAtMs = (payload['started_at'] as num?)?.toInt();
    final existing = _sessions[callId];
    _sessions[callId] = RecordingSession(
      callId: callId,
      filePath: payload['file_path'] as String? ?? existing?.filePath,
      phase: RecordingPhase.recording,
      startedAt: startedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(startedAtMs)
          : existing?.startedAt,
      autoRequested: existing?.autoRequested ?? false,
    );
    notifyListeners();
  }

  void handleRecordingStopped(Map<String, dynamic> payload) {
    final callId = (payload['call_id'] as num?)?.toInt();
    if (callId == null) return;
    final existing = _sessions[callId];
    _sessions[callId] = (existing ??
            RecordingSession(
              callId: callId,
              filePath: payload['file_path'] as String?,
              phase: RecordingPhase.stopped,
            ))
        .copyWith(
      filePath: payload['file_path'] as String?,
      phase: RecordingPhase.stopped,
      endedAt: DateTime.now(),
      clearErrorCode: true,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void handleRecordingSaved(Map<String, dynamic> payload) {
    final callId = (payload['call_id'] as num?)?.toInt();
    if (callId == null) return;
    final existing = _sessions[callId];
    final startedAtMs = (payload['started_at'] as num?)?.toInt();
    final endedAtMs = (payload['ended_at'] as num?)?.toInt();
    _sessions[callId] = (existing ??
            RecordingSession(
              callId: callId,
              filePath: payload['absolute_file_path'] as String?,
              phase: RecordingPhase.stopped,
            ))
        .copyWith(
      filePath: payload['absolute_file_path'] as String?,
      phase: RecordingPhase.stopped,
      startedAt: startedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(startedAtMs)
          : existing?.startedAt,
      endedAt: endedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(endedAtMs)
          : existing?.endedAt,
      durationMs: (payload['duration_ms'] as num?)?.toInt(),
      clearErrorCode: true,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void handleRecordingError(Map<String, dynamic> payload) {
    final callId = (payload['call_id'] as num?)?.toInt();
    if (callId == null) return;
    final existing = _sessions[callId];
    _sessions[callId] = (existing ??
            RecordingSession(
              callId: callId,
              filePath: null,
              phase: RecordingPhase.failed,
            ))
        .copyWith(
      phase: RecordingPhase.failed,
      errorCode: payload['code'] as String?,
      errorMessage: payload['message'] as String?,
    );
    notifyListeners();
  }

  void handleCallEnded(int callId, {String? finalRecordingPath}) {
    final existing = _sessions[callId];
    _pendingAutoStart.remove(callId);
    if (existing == null) {
      if (finalRecordingPath != null && finalRecordingPath.isNotEmpty) {
        _sessions[callId] = RecordingSession(
          callId: callId,
          filePath: finalRecordingPath,
          phase: RecordingPhase.stopped,
          endedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return;
    }
    _sessions[callId] = existing.copyWith(
      filePath: finalRecordingPath ?? existing.filePath,
      phase: existing.phase == RecordingPhase.recording
          ? RecordingPhase.stopping
          : existing.phase,
    );
    notifyListeners();
  }

  Future<List<File>> getRecordings() async {
    try {
      final dir = await getRecordingsDir();
      final files = await dir.list(recursive: true).toList();
      return files
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.wav'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
    } catch (e) {
      debugPrint('[RecordingService] Error getting recordings: $e');
      return <File>[];
    }
  }

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

  static String _formatCompactTimestamp(DateTime timestamp) {
    final y = timestamp.year.toString().padLeft(4, '0');
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }

  Future<String> _defaultRecordingsDirPath() async {
    final desktopDir = _desktopDirectoryPath();
    if (desktopDir != null && desktopDir.trim().isNotEmpty) {
      return p.join(desktopDir, 'Recordings');
    }
    return p.join(
      (await PathProviderService.instance.getDataDirectory()).path,
      'recordings',
    );
  }

  String? _desktopDirectoryPath() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      final userProfile = env['USERPROFILE'];
      if (userProfile != null && userProfile.trim().isNotEmpty) {
        return p.join(userProfile, 'Desktop');
      }
      final homeDrive = env['HOMEDRIVE'];
      final homePath = env['HOMEPATH'];
      if (homeDrive != null &&
          homeDrive.trim().isNotEmpty &&
          homePath != null &&
          homePath.trim().isNotEmpty) {
        return p.join('$homeDrive$homePath', 'Desktop');
      }
    } else {
      final home = env['HOME'];
      if (home != null && home.trim().isNotEmpty) {
        return p.join(home, 'Desktop');
      }
    }
    return null;
  }
}

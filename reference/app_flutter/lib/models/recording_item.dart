import 'dart:io';
import 'package:path/path.dart' as p;
import '../core/recording_service.dart';

/// Represents a call recording item with metadata from RecordingSession.
class RecordingItem {
  final String filePath;
  final String fileName;
  final int callId;
  final DateTime createdAt;
  final int fileSizeBytes;
  final Duration? duration;
  final bool autoRecorded;
  final RecordingSession? session;

  RecordingItem({
    required this.filePath,
    required this.fileName,
    required this.callId,
    required this.createdAt,
    required this.fileSizeBytes,
    this.duration,
    this.autoRecorded = false,
    this.session,
  });

  /// Create from session data and file.
  factory RecordingItem.fromSessionData({
    required File file,
    required int callId,
    required RecordingSession? session,
  }) {
    final fileName = p.basename(file.path);
    final match = RegExp(r'(\d+)_(\d{8}_\d{6})\.wav').firstMatch(fileName);

    DateTime createdAt;
    if (match != null) {
      final timestamp = match.group(2)!;
      createdAt = _parseTimestamp(timestamp);
    } else {
      // Fall back to file modification time
      try {
        createdAt = file.lastModifiedSync();
      } catch (_) {
        createdAt = DateTime.now();
      }
    }

    // Get duration from session if available
    Duration? duration;
    if (session?.durationMs != null && session!.durationMs! > 0) {
      duration = Duration(milliseconds: session.durationMs!);
    }

    return RecordingItem(
      filePath: file.path,
      fileName: fileName,
      callId: callId,
      createdAt: createdAt,
      fileSizeBytes: file.lengthSync(),
      duration: duration,
      autoRecorded: session?.autoRequested ?? false,
      session: session,
    );
  }

  /// Format file size for display.
  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Format date for display.
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      return 'Today, ${_formatTime(createdAt)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${_formatTime(createdAt)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return _formatDate(createdAt);
    }
  }

  /// Format duration for display.
  String get formattedDuration {
    if (duration == null) return '--:--';
    return _formatDuration(duration!);
  }

  static DateTime _parseTimestamp(String timestamp) {
    // Parse YYYYMMDD_HHMMSS format
    final year = int.parse(timestamp.substring(0, 4));
    final month = int.parse(timestamp.substring(4, 6));
    final day = int.parse(timestamp.substring(6, 8));
    final hour = int.parse(timestamp.substring(9, 11));
    final minute = int.parse(timestamp.substring(11, 13));
    final second = int.parse(timestamp.substring(13, 15));

    return DateTime(year, month, day, hour, minute, second);
  }

  static String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => 'RecordingItem(callId: $callId, fileName: $fileName, createdAt: $createdAt)';
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../core/recording_service.dart';
import '../models/recording_item.dart';

/// State for the recordings playlist.
class RecordingsState {
  final List<RecordingItem> recordings;
  final bool isLoading;
  final RecordingItem? currentRecording;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final bool isBuffering;

  RecordingsState({
    this.recordings = const [],
    this.isLoading = false,
    this.currentRecording,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.isBuffering = false,
  });

  RecordingsState copyWith({
    List<RecordingItem>? recordings,
    bool? isLoading,
    RecordingItem? currentRecording,
    bool? clearCurrentRecording = false,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isBuffering,
  }) {
    return RecordingsState(
      recordings: recordings ?? this.recordings,
      isLoading: isLoading ?? this.isLoading,
      currentRecording: clearCurrentRecording == true
          ? null
          : (currentRecording ?? this.currentRecording),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
    );
  }
}

/// Notifier for managing recordings state and playback using media_kit.
class RecordingsNotifier extends StateNotifier<RecordingsState> {
  final Player _player = Player();
  final List<StreamSubscription> _subscriptions = [];

  RecordingsNotifier() : super(RecordingsState()) {
    _init();
  }

  void _init() {
    // Listen to RecordingService changes
    RecordingService.instance.addListener(_onRecordingChanged);

    // Set up player event listeners
    // Note: position updates are direct (not scheduled) for smooth progress bar
    _subscriptions.add(_player.stream.playing.listen((playing) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        state = state.copyWith(isPlaying: playing);
      });
    }));

    _subscriptions.add(_player.stream.position.listen((position) {
      // Direct update for smooth progress bar animation
      state = state.copyWith(position: position);
    }));

    _subscriptions.add(_player.stream.duration.listen((duration) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        state = state.copyWith(duration: duration);
      });
    }));

    _subscriptions.add(_player.stream.buffering.listen((buffering) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        state = state.copyWith(isBuffering: buffering);
      });
    }));

    // Load recordings on init
    loadRecordings();
  }

  void _onRecordingChanged() {
    // Refresh list when recording starts/stops/completes
    loadRecordings();
  }

  /// Load all recordings from disk.
  Future<void> loadRecordings() async {
    state = state.copyWith(isLoading: true);

    try {
      final recordingsData = await RecordingService.instance.getRecordingsWithSessions();
      final items = recordingsData
          .map((data) => RecordingItem.fromSessionData(
                file: data['file'] as File,
                callId: data['callId'] as int,
                session: data['session'] as RecordingSession?,
              ))
          .toList();

      state = state.copyWith(
        recordings: items,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[RecordingsNotifier] Error loading recordings: $e');
      state = state.copyWith(
        recordings: [],
        isLoading: false,
      );
    }
  }

  /// Play a recording.
  Future<void> playRecording(RecordingItem recording) async {
    try {
      // If already playing this recording, toggle pause/play
      if (state.currentRecording?.filePath == recording.filePath) {
        if (state.isPlaying) {
          await pause();
        } else {
          await resume();
        }
        return;
      }

      // Stop current playback
      await _player.stop();

      // Set new source - use file:// URI for local files
      await _player.open(Media('file://${recording.filePath.replaceAll('\\', '/')}'));

      // Update state
      state = state.copyWith(
        currentRecording: recording,
        isPlaying: false,
        position: Duration.zero,
      );
    } catch (e, stack) {
      debugPrint('[RecordingsNotifier] Error playing recording: $e');
      debugPrint('Stack trace: $stack');
      // Clear current recording on error
      state = state.copyWith(
        clearCurrentRecording: true,
        duration: null,
        isBuffering: false,
      );
      rethrow;
    }
  }

  /// Pause playback.
  Future<void> pause() async {
    await _player.pause();
  }

  /// Resume playback.
  Future<void> resume() async {
    await _player.play();
  }

  /// Stop playback.
  Future<void> stop() async {
    await _player.stop();
    state = state.copyWith(
      isPlaying: false,
      position: Duration.zero,
      clearCurrentRecording: true,
      duration: null,
      isBuffering: false,
    );
  }

  /// Seek to a position.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Delete a recording.
  Future<bool> deleteRecording(RecordingItem recording) async {
    try {
      // Stop if currently playing this recording
      if (state.currentRecording?.filePath == recording.filePath) {
        await stop();
      }

      final deleted = await RecordingService.instance.deleteRecording(recording.filePath);

      if (deleted) {
        // Refresh the list
        await loadRecordings();
      }

      return deleted;
    } catch (e) {
      debugPrint('[RecordingsNotifier] Error deleting recording: $e');
      return false;
    }
  }

  /// Get the active recording session (if any recording is currently being recorded).
  RecordingSession? getActiveRecordingSession() {
    for (final recording in state.recordings) {
      if (recording.session?.isActive == true) {
        return recording.session;
      }
    }
    return null;
  }

  @override
  void dispose() {
    RecordingService.instance.removeListener(_onRecordingChanged);
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}

/// Provider for recordings state.
final recordingsProvider = StateNotifierProvider<RecordingsNotifier, RecordingsState>((ref) {
  return RecordingsNotifier();
});

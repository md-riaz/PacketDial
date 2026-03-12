import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
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
  final ProcessingState processingState;

  RecordingsState({
    this.recordings = const [],
    this.isLoading = false,
    this.currentRecording,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.processingState = ProcessingState.idle,
  });

  RecordingsState copyWith({
    List<RecordingItem>? recordings,
    bool? isLoading,
    RecordingItem? currentRecording,
    bool? clearCurrentRecording = false,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    ProcessingState? processingState,
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
      processingState: processingState ?? this.processingState,
    );
  }
}

/// Notifier for managing recordings state and playback.
class RecordingsNotifier extends StateNotifier<RecordingsState> {
  final AudioPlayer _player = AudioPlayer();

  RecordingsNotifier() : super(RecordingsState()) {
    _init();
  }

  void _init() {
    // Listen to RecordingService changes
    RecordingService.instance.addListener(_onRecordingChanged);

    // Set up player state listeners
    _player.playerStateStream.listen((playerState) {
      state = state.copyWith(
        isPlaying: playerState.playing,
        processingState: playerState.processingState,
      );
    });

    // Listen to position updates
    _player.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    // Listen to duration updates
    _player.durationStream.listen((duration) {
      state = state.copyWith(duration: duration);
    });

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
      final files = await RecordingService.instance.getRecordings();
      final items = files
          .map((f) => RecordingItem.fromFile(f))
          .whereType<RecordingItem>()
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

      // Set new source
      await _player.setFilePath(recording.filePath);

      // Update state
      state = state.copyWith(
        currentRecording: recording,
        isPlaying: false,
        position: Duration.zero,
      );

      // Start playback
      await _player.play();
    } catch (e) {
      debugPrint('[RecordingsNotifier] Error playing recording: $e');
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
    _player.dispose();
    super.dispose();
  }
}

/// Provider for recordings state.
final recordingsProvider = StateNotifierProvider<RecordingsNotifier, RecordingsState>((ref) {
  return RecordingsNotifier();
});

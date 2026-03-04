import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service to handle application-level audio feedback (ringtones, ringback).
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _ringbackPlayer = AudioPlayer();
  final AudioPlayer _uiPlayer = AudioPlayer();

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
    _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
    _initialized = true;
  }

  Future<void> startRingtone() async {
    try {
      if (_ringtonePlayer.state == PlayerState.playing) return;
      await _ringtonePlayer.play(AssetSource('sounds/ringtone.wav'));
    } catch (e) {
      debugPrint('[AudioService] Failed to start ringtone: $e');
    }
  }

  Future<void> startRingback() async {
    try {
      if (_ringbackPlayer.state == PlayerState.playing) return;
      await _ringbackPlayer.play(AssetSource('sounds/ringback.wav'));
    } catch (e) {
      debugPrint('[AudioService] Failed to start ringback: $e');
    }
  }

  Future<void> stopAll() async {
    try {
      await _ringtonePlayer.stop();
      await _ringbackPlayer.stop();
    } catch (e) {
      debugPrint('[AudioService] Failed to stop audio: $e');
    }
  }

  Future<void> playDialTone(String digit) async {
    try {
      String assetName = digit;
      if (digit == '*') assetName = 'star';
      if (digit == '#') assetName = 'hash';

      // Use low latency player for immediate digit feedback
      await _uiPlayer.play(
        AssetSource('sounds/dtmf_$assetName.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('[AudioService] Failed to play DTMF asset for $digit: $e');
    }
  }

  void dispose() {
    _ringtonePlayer.dispose();
    _ringbackPlayer.dispose();
    _uiPlayer.dispose();
  }
}

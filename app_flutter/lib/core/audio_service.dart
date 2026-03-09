import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Service to handle application-level audio feedback (ringtones, ringback, DTMF).
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _ringbackPlayer = AudioPlayer();
  final AudioPlayer _uiPlayer = AudioPlayer();

  bool _initialized = false;
  bool _ringtoneLoaded = false;
  bool _ringbackLoaded = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _ringtonePlayer.setLoopMode(LoopMode.one);
    _ringbackPlayer.setLoopMode(LoopMode.one);
  }

  Future<void> startRingtone() async {
    try {
      init();
      if (!_ringtoneLoaded) {
        await _ringtonePlayer.setAsset('assets/sounds/ringtone.wav');
        _ringtoneLoaded = true;
      }
      await _ringtonePlayer.play();
    } catch (e) {
      debugPrint('[AudioService] Failed to start ringtone: $e');
    }
  }

  Future<void> startRingback() async {
    try {
      init();
      if (!_ringbackLoaded) {
        await _ringbackPlayer.setAsset('assets/sounds/ringback.wav');
        _ringbackLoaded = true;
      }
      await _ringbackPlayer.play();
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
      init();
      var assetName = digit;
      if (digit == '*') assetName = 'star';
      if (digit == '#') assetName = 'hash';

      await _uiPlayer.setAsset('assets/sounds/dtmf_$assetName.wav');
      await _uiPlayer.play();
    } catch (e) {
      debugPrint('[AudioService] Failed to play DTMF asset for $digit: $e');
    }
  }

  Future<void> dispose() async {
    await _ringtonePlayer.dispose();
    await _ringbackPlayer.dispose();
    await _uiPlayer.dispose();
  }
}

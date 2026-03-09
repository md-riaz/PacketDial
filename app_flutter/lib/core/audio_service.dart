import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service to handle application-level audio feedback (ringtones, ringback, DTMF).
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _ringbackPlayer = AudioPlayer();
  final AudioPlayer _uiPlayer = AudioPlayer();

  bool _initialized = false;
  bool _configured = false;
  void init() {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (_) {
      _configured = false;
      rethrow;
    }
  }

  Future<void> startRingtone() async {
    try {
      init();
      await _ensureConfigured();
      if (_ringtonePlayer.state != PlayerState.playing) {
        await _ringtonePlayer.play(AssetSource('sounds/ringtone.wav'));
      }
    } catch (e) {
      debugPrint('[AudioService] Failed to start ringtone: $e');
    }
  }

  Future<void> startRingback() async {
    try {
      init();
      await _ensureConfigured();
      if (_ringbackPlayer.state != PlayerState.playing) {
        await _ringbackPlayer.play(AssetSource('sounds/ringback.wav'));
      }
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

      await _uiPlayer.play(AssetSource('sounds/dtmf_$assetName.wav'));
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

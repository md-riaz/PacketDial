import 'package:just_audio/just_audio.dart';
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
  bool _ringtonePlaying = false;
  bool _ringbackPlaying = false;
  Future<void> _opChain = Future<void>.value();

  void init() {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    try {
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      await _ringbackPlayer.setLoopMode(LoopMode.one);
    } catch (_) {
      _configured = false;
      rethrow;
    }
  }

  Future<void> _enqueue(Future<void> Function() op) {
    _opChain = _opChain.then((_) => op()).catchError((e, _) {
      debugPrint('[AudioService] Audio operation failed: $e');
    });
    return _opChain;
  }

  Future<void> startRingtone() async {
    return _enqueue(() async {
      try {
        init();
        await _ensureConfigured();
        if (_ringtonePlaying) return;
        _ringtonePlaying = true;
        await _ringtonePlayer.setAsset('assets/sounds/ringtone.wav');
        await _ringtonePlayer.play();
      } catch (e) {
        _ringtonePlaying = false;
        debugPrint('[AudioService] Failed to start ringtone: $e');
      }
    });
  }

  Future<void> startRingback() async {
    return _enqueue(() async {
      try {
        init();
        await _ensureConfigured();
        if (_ringbackPlaying) return;
        _ringbackPlaying = true;
        await _ringbackPlayer.setAsset('assets/sounds/ringback.wav');
        await _ringbackPlayer.play();
      } catch (e) {
        _ringbackPlaying = false;
        debugPrint('[AudioService] Failed to start ringback: $e');
      }
    });
  }

  Future<void> stopAll() async {
    return _enqueue(() async {
      try {
        await _ringtonePlayer.stop();
        await _ringbackPlayer.stop();
        _ringtonePlaying = false;
        _ringbackPlaying = false;
      } catch (e) {
        debugPrint('[AudioService] Failed to stop audio: $e');
      }
    });
  }

  Future<void> playDialTone(String digit) async {
    return _enqueue(() async {
      try {
        init();
        var assetName = digit;
        if (digit == '*') assetName = 'star';
        if (digit == '#') assetName = 'hash';

        await _uiPlayer.stop();
        await _uiPlayer.setAsset('assets/sounds/dtmf_$assetName.wav');
        await _uiPlayer.seek(Duration.zero);
        await _uiPlayer.play();
      } catch (e) {
        debugPrint('[AudioService] Failed to play DTMF asset for $digit: $e');
      }
    });
  }

  Future<void> dispose() async {
    await _ringtonePlayer.dispose();
    await _ringbackPlayer.dispose();
    await _uiPlayer.dispose();
  }
}

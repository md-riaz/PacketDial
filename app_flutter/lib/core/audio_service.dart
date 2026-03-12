import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:media_kit/media_kit.dart';
import 'call_event_service.dart';

/// Service to handle application-level audio feedback (ringtones, ringback, DTMF).
///
/// Uses media_kit for all platforms including Windows.
///
/// ## Thread Safety
/// All audio operations are scheduled on the platform thread to prevent
/// threading violations with platform channels.
class AudioService {
  AudioService._() {
    // Subscribe to call events on initialization
    _setupCallEventListeners();
  }

  static final AudioService instance = AudioService._();

  // media_kit players
  final Player _ringtonePlayer = Player();
  final Player _ringbackPlayer = Player();
  final Player _uiPlayer = Player();

  bool _initialized = false;
  bool _ringtonePlaying = false;
  bool _ringbackPlaying = false;
  Future<void> _opChain = Future<void>.value();

  void _setupCallEventListeners() {
    CallEventService.instance.eventStream.listen(_onCallEvent);
  }

  void _onCallEvent(CallEvent event) {
    // FlutterEventBus already ensures we're on the platform thread
    final state = event.state.toLowerCase();
    final direction = event.direction.toLowerCase();

    if (state == 'callstate.ringing') {
      if (direction == 'incoming') {
        // Guard: Only start ringtone if not already playing
        if (!_ringtonePlaying) {
          startRingtone();
        }
      } else {
        // Guard: Only start ringback if not already playing
        if (!_ringbackPlaying) {
          startRingback();
        }
      }
    } else if (state == 'callstate.incall' || state == 'callstate.ended') {
      // Always stop - don't check flags as they might be out of sync
      stopAll();
    }
  }

  void init() {
    if (_initialized) return;
    _initialized = true;
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
        if (_ringtonePlaying) return;
        _ringtonePlaying = true;

        await _ringtonePlayer.open(Media('asset://assets/sounds/ringtone.wav'));
        await _ringtonePlayer.setPlaylistMode(PlaylistMode.loop);
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
        if (_ringbackPlaying) return;
        _ringbackPlaying = true;

        await _ringbackPlayer.open(Media('asset://assets/sounds/ringback.wav'));
        await _ringbackPlayer.setPlaylistMode(PlaylistMode.loop);
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

        final assetPath = 'assets/sounds/dtmf_$assetName.wav';

        await _uiPlayer.stop();
        await _uiPlayer.open(Media('asset://$assetPath'));
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

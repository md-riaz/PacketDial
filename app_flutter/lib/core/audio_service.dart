import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';
import 'package:just_audio/just_audio.dart';

import 'call_event_service.dart';

/// Service to handle application-level audio feedback (ringtones, ringback, DTMF).
///
/// On Windows, uses native PlaySoundW API to avoid just_audio threading issues.
/// On other platforms, uses just_audio.
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

  // just_audio players (non-Windows only)
  final AudioPlayer? _ringtonePlayer = _useWindowsNativeAudio ? null : AudioPlayer();
  final AudioPlayer? _ringbackPlayer = _useWindowsNativeAudio ? null : AudioPlayer();
  final AudioPlayer? _uiPlayer = _useWindowsNativeAudio ? null : AudioPlayer();

  // Windows native player
  final _WindowsWavePlayer _windowsPlayer = _WindowsWavePlayer();

  bool _initialized = false;
  bool _configured = false;
  bool _ringtonePlaying = false;
  bool _ringbackPlaying = false;
  Future<void> _opChain = Future<void>.value();

  static bool get _useWindowsNativeAudio => !kIsWeb && Platform.isWindows;

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
    } else if (state == 'callstate.incall' || state == 'ended') {
      // Guard: Only stop if something is actually playing
      if (_ringtonePlaying || _ringbackPlaying) {
        stopAll();
      }
    }
  }

  void init() {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    try {
      await _ringtonePlayer?.setLoopMode(LoopMode.one);
      await _ringbackPlayer?.setLoopMode(LoopMode.one);
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
        if (_ringtonePlaying) return;
        _ringtonePlaying = true;

        if (_useWindowsNativeAudio) {
          await _windowsPlayer.playLoopingAsset('assets/sounds/ringtone.wav');
          return;
        }

        await _ensureConfigured();
        await _ringtonePlayer?.setAsset('assets/sounds/ringtone.wav');
        await _ringtonePlayer?.play();
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

        if (_useWindowsNativeAudio) {
          await _windowsPlayer.playLoopingAsset('assets/sounds/ringback.wav');
          return;
        }

        await _ensureConfigured();
        await _ringbackPlayer?.setAsset('assets/sounds/ringback.wav');
        await _ringbackPlayer?.play();
      } catch (e) {
        _ringbackPlaying = false;
        debugPrint('[AudioService] Failed to start ringback: $e');
      }
    });
  }

  Future<void> stopAll() async {
    return _enqueue(() async {
      try {
        if (_useWindowsNativeAudio) {
          _windowsPlayer.stop();
        } else {
          await _ringtonePlayer?.stop();
          await _ringbackPlayer?.stop();
        }
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
        if (_useWindowsNativeAudio) {
          await _windowsPlayer.playOneShotAsset(assetPath);
          return;
        }

        await _uiPlayer?.stop();
        await _uiPlayer?.setAsset(assetPath);
        await _uiPlayer?.seek(Duration.zero);
        await _uiPlayer?.play();
      } catch (e) {
        debugPrint('[AudioService] Failed to play DTMF asset for $digit: $e');
      }
    });
  }

  Future<void> dispose() async {
    if (_useWindowsNativeAudio) {
      _windowsPlayer.stop();
      return;
    }
    await _ringtonePlayer?.dispose();
    await _ringbackPlayer?.dispose();
    await _uiPlayer?.dispose();
  }
}

/// Windows native audio player using PlaySoundW API.
class _WindowsWavePlayer {
  static const int _sndAsync = 0x0001;
  static const int _sndFilename = 0x00020000;
  static const int _sndLoop = 0x0008;
  static const int _sndNodefault = 0x0002;

  late final ffi.DynamicLibrary _library = ffi.DynamicLibrary.open('winmm.dll');
  late final int Function(ffi.Pointer<Utf16>, int, int) _playSound = _library
      .lookupFunction<
          ffi.Int32 Function(ffi.Pointer<Utf16>, ffi.IntPtr, ffi.Uint32),
          int Function(ffi.Pointer<Utf16>, int, int)>('PlaySoundW');

  final Map<String, Future<String>> _assetCache = {};

  Future<void> playLoopingAsset(String assetPath) async {
    final filePath = await _materializeAsset(assetPath);
    final ok = _invokePlaySound(
      filePath,
      flags: _sndAsync | _sndFilename | _sndLoop | _sndNodefault,
    );
    if (!ok) {
      throw StateError('PlaySoundW failed for looping asset: $assetPath');
    }
  }

  Future<void> playOneShotAsset(String assetPath) async {
    final filePath = await _materializeAsset(assetPath);
    final ok = _invokePlaySound(
      filePath,
      flags: _sndAsync | _sndFilename | _sndNodefault,
    );
    if (!ok) {
      throw StateError('PlaySoundW failed for asset: $assetPath');
    }
  }

  void stop() {
    _playSound(ffi.nullptr, 0, 0);
  }

  bool _invokePlaySound(String filePath, {required int flags}) {
    final pathPtr = filePath.toNativeUtf16();
    try {
      return _playSound(pathPtr, 0, flags) != 0;
    } finally {
      calloc.free(pathPtr);
    }
  }

  Future<String> _materializeAsset(String assetPath) {
    return _assetCache.putIfAbsent(assetPath, () async {
      final data = await rootBundle.load(assetPath);
      final buffer = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final tempDir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}packetdial_audio',
      );
      await tempDir.create(recursive: true);
      final fileName = assetPath.replaceAll('/', '_');
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(buffer, flush: true);
      return file.path;
    });
  }
}

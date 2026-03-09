import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';

/// Service to handle application-level audio feedback (ringtones, ringback).
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();
  static const bool _enableLoopCallTones = false;

  static const int _sndAsync = 0x0001;
  static const int _sndNoDefault = 0x0002;
  static const int _sndLoop = 0x0008;
  static const int _sndFilename = 0x00020000;

  int Function(
    ffi.Pointer<Utf16>,
    ffi.Pointer<ffi.Void>,
    int,
  )? _playSoundW;
  String? _activeLoopFile;
  ffi.Pointer<Utf16>? _activeLoopPathPtr;

  void init() {
    if (!Platform.isWindows) return;
    try {
      final winmm = ffi.DynamicLibrary.open('winmm.dll');
      _playSoundW = winmm.lookupFunction<
          ffi.Int32 Function(
              ffi.Pointer<Utf16>, ffi.Pointer<ffi.Void>, ffi.Uint32),
          int Function(
              ffi.Pointer<Utf16>, ffi.Pointer<ffi.Void>, int)>('PlaySoundW');
    } catch (e) {
      debugPrint('[AudioService] Failed to initialize winmm audio: $e');
    }
  }

  Future<void> startRingtone() async {
    try {
      if (!_enableLoopCallTones) return;
      _playLoopingAsset('ringtone.wav');
    } catch (e) {
      debugPrint('[AudioService] Failed to start ringtone: $e');
    }
  }

  Future<void> startRingback() async {
    try {
      if (!_enableLoopCallTones) return;
      _playLoopingAsset('ringback.wav');
    } catch (e) {
      debugPrint('[AudioService] Failed to start ringback: $e');
    }
  }

  Future<void> stopAll() async {
    try {
      if (!Platform.isWindows) return;
      _playSoundW?.call(ffi.nullptr, ffi.nullptr, 0);
      _activeLoopFile = null;
      _freeActiveLoopPath();
    } catch (e) {
      debugPrint('[AudioService] Failed to stop audio: $e');
    }
  }

  Future<void> playDialTone(String digit) async {
    try {
      String assetName = digit;
      if (digit == '*') assetName = 'star';
      if (digit == '#') assetName = 'hash';

      _playOneShotAsset('dtmf_$assetName.wav');
    } catch (e) {
      debugPrint('[AudioService] Failed to play DTMF asset for $digit: $e');
    }
  }

  void _playLoopingAsset(String fileName) {
    if (!Platform.isWindows) return;
    if (_playSoundW == null) return;
    if (_activeLoopFile == fileName && _activeLoopPathPtr != null) {
      return;
    }
    final path = _resolveSoundPath(fileName);
    if (path == null) {
      debugPrint('[AudioService] Sound asset not found: $fileName');
      return;
    }

    _freeActiveLoopPath();
    final ptr = path.toNativeUtf16();
    final rc = _playSoundW!.call(
      ptr,
      ffi.nullptr,
      _sndAsync | _sndFilename | _sndNoDefault | _sndLoop,
    );
    if (rc != 0) {
      _activeLoopFile = fileName;
      _activeLoopPathPtr = ptr;
    } else {
      calloc.free(ptr);
      debugPrint('[AudioService] PlaySoundW failed for loop asset: $fileName');
    }
  }

  void _playOneShotAsset(String fileName) {
    if (!Platform.isWindows) return;
    if (_playSoundW == null) return;
    final path = _resolveSoundPath(fileName);
    if (path == null) {
      debugPrint('[AudioService] Sound asset not found: $fileName');
      return;
    }

    final ptr = path.toNativeUtf16();
    try {
      _playSoundW!
          .call(ptr, ffi.nullptr, _sndAsync | _sndFilename | _sndNoDefault);
    } finally {
      calloc.free(ptr);
    }
  }

  String? _resolveSoundPath(String fileName) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      '$exeDir\\data\\flutter_assets\\assets\\sounds\\$fileName',
      '${Directory.current.path}\\assets\\sounds\\$fileName',
      '${Directory.current.path}\\data\\flutter_assets\\assets\\sounds\\$fileName',
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  void dispose() {}

  void _freeActiveLoopPath() {
    final ptr = _activeLoopPathPtr;
    if (ptr != null) {
      calloc.free(ptr);
      _activeLoopPathPtr = null;
    }
  }
}

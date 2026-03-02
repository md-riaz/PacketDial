import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:flutter/foundation.dart';

typedef _EngineInitC = ffi.Int32 Function();
typedef _EngineShutdownC = ffi.Int32 Function();
typedef _EngineVersionC = ffi.Pointer<ffi.Int8> Function();

class VoipEngine {
  final ffi.DynamicLibrary _lib;

  late final int Function() _init = _lib
      .lookupFunction<_EngineInitC, int Function()>('engine_init');
  late final int Function() _shutdown = _lib
      .lookupFunction<_EngineShutdownC, int Function()>('engine_shutdown');
  late final ffi.Pointer<ffi.Int8> Function() _version = _lib
      .lookupFunction<_EngineVersionC, ffi.Pointer<ffi.Int8> Function()>('engine_version');

  VoipEngine._(this._lib);

  static VoipEngine load() {
    // For Windows development, we copy voip_core.dll into windows/runner/
    // so the executable can find it via the working directory.
    if (!Platform.isWindows) {
      throw UnsupportedError('This scaffold currently targets Windows desktop.');
    }
    final lib = ffi.DynamicLibrary.open('voip_core.dll');
    return VoipEngine._(lib);
  }

  int init() => _init();
  int shutdown() => _shutdown();

  String version() {
    final ptr = _version();
    if (ptr == ffi.nullptr) return 'unknown';
    // Convert UTF-8 C string to Dart string manually
    final bytes = <int>[];
    int i = 0;
    while (true) {
      final v = ptr.elementAt(i).value;
      if (v == 0) break;
      bytes.add(v);
      i++;
    }
    return String.fromCharCodes(bytes);
  }
}

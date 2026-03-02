import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi_alloc;

typedef _EngineInitC = ffi.Int32 Function();
typedef _EngineShutdownC = ffi.Int32 Function();
typedef _EngineVersionC = ffi.Pointer<ffi.Int8> Function();
typedef _EngineSendCommandC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EnginePollEventC = ffi.Pointer<ffi.Int8> Function();
typedef _EngineFreeStringC = ffi.Void Function(ffi.Pointer<ffi.Int8>);

class VoipEngine {
  final ffi.DynamicLibrary _lib;

  late final int Function() _init =
      _lib.lookupFunction<_EngineInitC, int Function()>('engine_init');
  late final int Function() _shutdown =
      _lib.lookupFunction<_EngineShutdownC, int Function()>('engine_shutdown');
  late final ffi.Pointer<ffi.Int8> Function() _version = _lib
      .lookupFunction<_EngineVersionC, ffi.Pointer<ffi.Int8> Function()>(
          'engine_version');
  late final int Function(ffi.Pointer<ffi.Int8>) _sendCommand = _lib
      .lookupFunction<_EngineSendCommandC,
          int Function(ffi.Pointer<ffi.Int8>)>('engine_send_command');
  late final ffi.Pointer<ffi.Int8> Function() _pollEvent = _lib
      .lookupFunction<_EnginePollEventC, ffi.Pointer<ffi.Int8> Function()>(
          'engine_poll_event');
  late final void Function(ffi.Pointer<ffi.Int8>) _freeString = _lib
      .lookupFunction<_EngineFreeStringC,
          void Function(ffi.Pointer<ffi.Int8>)>('engine_free_string');

  VoipEngine._(this._lib);

  static VoipEngine load() {
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
    return _ptrToString(ptr);
  }

  /// Send a JSON command string to the engine core.
  /// Returns 0 on success, non-zero on error.
  int sendCommand(String cmdJson) {
    final bytes = _stringToBytes(cmdJson);
    final ptr = _allocBytes(bytes);
    final rc = _sendCommand(ptr);
    _freeNative(ptr);
    return rc;
  }

  /// Poll for the next event JSON string, or null if none queued.
  String? pollEvent() {
    final ptr = _pollEvent();
    if (ptr == ffi.nullptr) return null;
    final s = _ptrToString(ptr);
    _freeString(ptr);
    return s;
  }

  // ---- helpers ---------------------------------------------------------------

  /// Read a null-terminated UTF-8 C string from [ptr] into a Dart [String].
  String _ptrToString(ffi.Pointer<ffi.Int8> ptr) {
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

  /// Encode [s] as UTF-8 bytes with a null terminator.
  /// Handles the full Unicode range including surrogate pairs from Dart's
  /// UTF-16 [String.codeUnits].
  List<int> _stringToBytes(String s) {
    final encoded = <int>[];
    final units = s.codeUnits;
    int i = 0;
    while (i < units.length) {
      int codePoint = units[i];
      // Check for UTF-16 surrogate pair (code points U+10000..U+10FFFF)
      if (codePoint >= 0xD800 && codePoint <= 0xDBFF && i + 1 < units.length) {
        final low = units[i + 1];
        if (low >= 0xDC00 && low <= 0xDFFF) {
          codePoint =
              0x10000 + (codePoint - 0xD800) * 0x400 + (low - 0xDC00);
          i += 2;
        } else {
          i++;
        }
      } else {
        i++;
      }

      if (codePoint < 0x80) {
        encoded.add(codePoint);
      } else if (codePoint < 0x800) {
        encoded.add(0xC0 | (codePoint >> 6));
        encoded.add(0x80 | (codePoint & 0x3F));
      } else if (codePoint < 0x10000) {
        encoded.add(0xE0 | (codePoint >> 12));
        encoded.add(0x80 | ((codePoint >> 6) & 0x3F));
        encoded.add(0x80 | (codePoint & 0x3F));
      } else {
        encoded.add(0xF0 | (codePoint >> 18));
        encoded.add(0x80 | ((codePoint >> 12) & 0x3F));
        encoded.add(0x80 | ((codePoint >> 6) & 0x3F));
        encoded.add(0x80 | (codePoint & 0x3F));
      }
    }
    encoded.add(0); // null terminator
    return encoded;
  }

  /// Allocate a native Int8 array from [bytes] using the Dart FFI allocator.
  ffi.Pointer<ffi.Int8> _allocBytes(List<int> bytes) {
    final ptr =
        ffi_alloc.calloc.allocate<ffi.Int8>(ffi.sizeOf<ffi.Int8>() * bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      ptr.elementAt(i).value = bytes[i];
    }
    return ptr;
  }

  void _freeNative(ffi.Pointer<ffi.Int8> ptr) {
    ffi_alloc.calloc.free(ptr);
  }
}

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi_alloc;

typedef _EngineInitC = ffi.Int32 Function();
typedef _EngineShutdownC = ffi.Int32 Function();
typedef _EngineVersionC = ffi.Pointer<ffi.Int8> Function();

// Structured C ABI functions
typedef _EngineRegisterC = ffi.Int32 Function(
    ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>);
typedef _EngineUnregisterC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EngineMakeCallC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>);
typedef _EngineAnswerCallC = ffi.Int32 Function();
typedef _EngineHangupC = ffi.Int32 Function();
typedef _EngineSetMuteC = ffi.Int32 Function(ffi.Int32);
typedef _EngineSetHoldC = ffi.Int32 Function(ffi.Int32);
typedef _EngineListAudioDevicesC = ffi.Int32 Function();
typedef _EngineSetAudioDevicesC = ffi.Int32 Function(ffi.Int32, ffi.Int32);
typedef _EngineQueryCallHistoryC = ffi.Int32 Function();
typedef _EngineSetEventCallbackC = ffi.Void Function(
    ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>>);

/// Event IDs matching Rust EngineEventId enum.
abstract class EngineEventId {
  static const int engineReady = 1;
  static const int registrationStateChanged = 2;
  static const int callStateChanged = 3;
  static const int mediaStatsUpdated = 4;
  static const int audioDeviceList = 5;
  static const int audioDevicesSet = 6;
  static const int callHistoryResult = 7;
  static const int sipMessageCaptured = 8;
  static const int diagBundleReady = 9;
  static const int accountSecurityUpdated = 10;
  static const int credStored = 11;
  static const int credRetrieved = 12;
  static const int enginePong = 13;
  static const int logLevelSet = 14;
  static const int logBufferResult = 15;
  static const int engineLog = 16;
}

class VoipEngine {
  final ffi.DynamicLibrary _lib;

  late final int Function() _init =
      _lib.lookupFunction<_EngineInitC, int Function()>('engine_init');
  late final int Function() _shutdown =
      _lib.lookupFunction<_EngineShutdownC, int Function()>('engine_shutdown');
  late final ffi.Pointer<ffi.Int8> Function() _version = _lib
      .lookupFunction<_EngineVersionC, ffi.Pointer<ffi.Int8> Function()>(
          'engine_version');

  // Structured C ABI function lookups
  late final int Function(
          ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>)
      _register = _lib.lookupFunction<
          _EngineRegisterC,
          int Function(ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>,
              ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>)>('engine_register');
  late final int Function(ffi.Pointer<ffi.Int8>) _unregister = _lib
      .lookupFunction<_EngineUnregisterC, int Function(ffi.Pointer<ffi.Int8>)>(
          'engine_unregister');
  late final int Function(ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>) _makeCall = _lib
      .lookupFunction<_EngineMakeCallC, int Function(ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>)>(
          'engine_make_call');
  late final int Function() _answerCall =
      _lib.lookupFunction<_EngineAnswerCallC, int Function()>('engine_answer_call');
  late final int Function() _hangup =
      _lib.lookupFunction<_EngineHangupC, int Function()>('engine_hangup');
  late final int Function(int) _setMute =
      _lib.lookupFunction<_EngineSetMuteC, int Function(int)>('engine_set_mute');
  late final int Function(int) _setHold =
      _lib.lookupFunction<_EngineSetHoldC, int Function(int)>('engine_set_hold');
  late final int Function() _listAudioDevices =
      _lib.lookupFunction<_EngineListAudioDevicesC, int Function()>(
          'engine_list_audio_devices');
  late final int Function(int, int) _setAudioDevices =
      _lib.lookupFunction<_EngineSetAudioDevicesC, int Function(int, int)>(
          'engine_set_audio_devices');
  late final int Function() _queryCallHistory =
      _lib.lookupFunction<_EngineQueryCallHistoryC, int Function()>(
          'engine_query_call_history');
  late final void Function(
          ffi.Pointer<
              ffi.NativeFunction<
                  ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>>)
      _setEventCallback = _lib.lookupFunction<
          _EngineSetEventCallbackC,
          void Function(
              ffi.Pointer<
                  ffi.NativeFunction<
                      ffi.Void Function(
                          ffi.Int32, ffi.Pointer<ffi.Int8>)>>)>(
          'engine_set_event_callback');

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

  // ---- Structured C ABI methods ----------------------------------------

  /// Register a SIP account directly.
  /// Returns 0 on success, non-zero on error.
  int register(String accountId, String user, String pass, String domain) {
    final accountIdPtr = _allocCString(accountId);
    final userPtr = _allocCString(user);
    final passPtr = _allocCString(pass);
    final domainPtr = _allocCString(domain);
    try {
      return _register(accountIdPtr, userPtr, passPtr, domainPtr);
    } finally {
      _freeNative(accountIdPtr);
      _freeNative(userPtr);
      _freeNative(passPtr);
      _freeNative(domainPtr);
    }
  }

  /// Unregister a SIP account.
  /// Returns 0 on success, non-zero on error.
  int unregister(String accountId) {
    final ptr = _allocCString(accountId);
    try {
      return _unregister(ptr);
    } finally {
      _freeNative(ptr);
    }
  }

  /// Make an outgoing call.
  /// [accountId] is the account ID to use for the call.
  /// [number] is a SIP URI or phone number.
  /// Returns 0 on success, non-zero on error.
  int makeCall(String accountId, String number) {
    final accountIdPtr = _allocCString(accountId);
    final numberPtr = _allocCString(number);
    try {
      return _makeCall(accountIdPtr, numberPtr);
    } finally {
      _freeNative(accountIdPtr);
      _freeNative(numberPtr);
    }
  }

  /// Answer an incoming call.
  /// Returns 0 on success, non-zero on error.
  int answerCall() => _answerCall();

  /// Hang up the current active call.
  /// Returns 0 on success, non-zero on error.
  int hangup() => _hangup();

  /// Toggle mute on the active call.
  /// [muted] should be true to mute, false to unmute.
  /// Returns 0 on success, non-zero on error.
  int setMute(bool muted) => _setMute(muted ? 1 : 0);

  /// Toggle hold on the active call.
  /// [onHold] should be true to hold, false to resume.
  /// Returns 0 on success, non-zero on error.
  int setHold(bool onHold) => _setHold(onHold ? 1 : 0);

  /// Request audio device list.
  /// This will trigger an AudioDeviceList event via the callback.
  /// Returns 0 on success, non-zero on error.
  int listAudioDevices() => _listAudioDevices();

  /// Set active audio devices.
  /// Returns 0 on success, non-zero on error.
  int setAudioDevices(int inputId, int outputId) =>
      _setAudioDevices(inputId, outputId);

  /// Request call history.
  /// This will trigger a CallHistoryResult event via the callback.
  /// Returns 0 on success, non-zero on error.
  int queryCallHistory() => _queryCallHistory();

  /// Set a native event callback function.
  ///
  /// Pass a [ffi.Pointer] to a native function with signature:
  ///   `void callback(int event_id, const char* json_data)`
  ///
  /// Pass [ffi.nullptr] to clear the callback.
  void setEventCallback(
      ffi.Pointer<
              ffi.NativeFunction<
                  ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>>
          cb) {
    _setEventCallback(cb);
  }

  // ---- helpers ---------------------------------------------------------------

  /// Allocate a null-terminated UTF-8 C string from a Dart [String].
  /// The caller is responsible for freeing the returned pointer via [_freeNative].
  ffi.Pointer<ffi.Int8> _allocCString(String s) {
    return _allocBytes(_stringToBytes(s));
  }

  /// Read a null-terminated UTF-8 C string from [ptr] into a Dart [String].
  String _ptrToString(ffi.Pointer<ffi.Int8> ptr) {
    final bytes = <int>[];
    int i = 0;
    while (true) {
      final v = (ptr + i).value;
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
      (ptr + i).value = bytes[i];
    }
    return ptr;
  }

  void _freeNative(ffi.Pointer<ffi.Int8> ptr) {
    ffi_alloc.calloc.free(ptr);
  }
}

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi_alloc;

typedef _EngineInitC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EngineShutdownC = ffi.Int32 Function();
typedef _EngineVersionC = ffi.Pointer<ffi.Int8> Function();

// Structured C ABI functions
typedef _EngineRegisterC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>,
    ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>);
typedef _EngineUnregisterC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EngineMakeCallC = ffi.Int32 Function(
    ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>);
typedef _EngineAnswerCallC = ffi.Int32 Function();
typedef _EngineHangupC = ffi.Int32 Function();
typedef _EngineSetMuteC = ffi.Int32 Function(ffi.Int32);
typedef _EngineSetHoldC = ffi.Int32 Function(ffi.Int32);
typedef _EngineListAudioDevicesC = ffi.Int32 Function();
typedef _EngineSetAudioDevicesC = ffi.Int32 Function(ffi.Int32, ffi.Int32);
typedef _EngineQueryCallHistoryC = ffi.Int32 Function();
typedef _EngineSetLogLevelC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EngineGetLogBufferC = ffi.Int32 Function();
typedef _EngineSendDtmfC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EnginePlayDtmfC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EngineTransferCallC = ffi.Int32 Function(
    ffi.Int32, ffi.Pointer<ffi.Int8>);
typedef _EngineStartAttendedXferC = ffi.Int32 Function(
    ffi.Int32, ffi.Pointer<ffi.Int8>);
typedef _EngineCompleteXferC = ffi.Int32 Function(ffi.Int32, ffi.Int32);
typedef _EngineMergeConferenceC = ffi.Int32 Function(ffi.Int32, ffi.Int32);
typedef _EngineStartRecordingC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EngineStopRecordingC = ffi.Int32 Function();
typedef _EngineIsRecordingC = ffi.Int32 Function();
typedef _EngineSendCommandC = ffi.Int32 Function(
    ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>);
typedef _EngineExportProfileC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EngineImportProfileC = ffi.Int32 Function(ffi.Pointer<ffi.Int8>);
typedef _EngineSetEventCallbackC = ffi.Void Function(
    ffi.Pointer<
        ffi
        .NativeFunction<ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>>);

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
  static const int callTransferInitiated = 17;
  static const int callTransferStatus = 18;
  static const int callTransferCompleted = 19;
  static const int conferenceMerged = 20;
}

class VoipEngine {
  final ffi.DynamicLibrary _lib;

  late final int Function(ffi.Pointer<ffi.Int8>) _init =
      _lib.lookupFunction<_EngineInitC, int Function(ffi.Pointer<ffi.Int8>)>(
          'engine_init');
  late final int Function() _shutdown =
      _lib.lookupFunction<_EngineShutdownC, int Function()>('engine_shutdown');
  late final ffi.Pointer<ffi.Int8> Function() _version =
      _lib.lookupFunction<_EngineVersionC, ffi.Pointer<ffi.Int8> Function()>(
          'engine_version');

  // Structured C ABI function lookups
  late final int Function(ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>,
          ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>) _register =
      _lib.lookupFunction<
          _EngineRegisterC,
          int Function(ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>,
              ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>)>('engine_register');
  late final int Function(ffi.Pointer<ffi.Int8>) _unregister = _lib
      .lookupFunction<_EngineUnregisterC, int Function(ffi.Pointer<ffi.Int8>)>(
          'engine_unregister');
  late final int Function(ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>)
      _makeCall = _lib.lookupFunction<
          _EngineMakeCallC,
          int Function(ffi.Pointer<ffi.Int8>,
              ffi.Pointer<ffi.Int8>)>('engine_make_call');
  late final int Function() _answerCall = _lib
      .lookupFunction<_EngineAnswerCallC, int Function()>('engine_answer_call');
  late final int Function() _hangup =
      _lib.lookupFunction<_EngineHangupC, int Function()>('engine_hangup');
  late final int Function(ffi.Pointer<ffi.Int8>) _exportProfile =
      _lib.lookupFunction<_EngineExportProfileC,
          int Function(ffi.Pointer<ffi.Int8>)>('engine_export_profile');
  late final int Function(ffi.Pointer<ffi.Int8>) _importProfile =
      _lib.lookupFunction<_EngineImportProfileC,
          int Function(ffi.Pointer<ffi.Int8>)>('engine_import_profile');
  late final int Function(int) _setMute = _lib
      .lookupFunction<_EngineSetMuteC, int Function(int)>('engine_set_mute');
  late final int Function(int) _setHold = _lib
      .lookupFunction<_EngineSetHoldC, int Function(int)>('engine_set_hold');
  late final int Function() _listAudioDevices =
      _lib.lookupFunction<_EngineListAudioDevicesC, int Function()>(
          'engine_list_audio_devices');
  late final int Function(int, int) _setAudioDevices =
      _lib.lookupFunction<_EngineSetAudioDevicesC, int Function(int, int)>(
          'engine_set_audio_devices');
  late final int Function() _queryCallHistory =
      _lib.lookupFunction<_EngineQueryCallHistoryC, int Function()>(
          'engine_query_call_history');
  late final int Function(ffi.Pointer<ffi.Int8>) _setLogLevel = _lib
      .lookupFunction<_EngineSetLogLevelC, int Function(ffi.Pointer<ffi.Int8>)>(
          'engine_set_log_level');
  late final int Function() _getLogBuffer =
      _lib.lookupFunction<_EngineGetLogBufferC, int Function()>(
          'engine_get_log_buffer');
  late final int Function(ffi.Pointer<ffi.Int8>) _sendDtmf = _lib
      .lookupFunction<_EngineSendDtmfC, int Function(ffi.Pointer<ffi.Int8>)>(
          'engine_send_dtmf');
  late final int Function(ffi.Pointer<ffi.Int8>) _playDtmf = _lib
      .lookupFunction<_EnginePlayDtmfC, int Function(ffi.Pointer<ffi.Int8>)>(
          'engine_play_dtmf');
  late final int Function(int, ffi.Pointer<ffi.Int8>) _transferCall =
      _lib.lookupFunction<_EngineTransferCallC,
          int Function(int, ffi.Pointer<ffi.Int8>)>('engine_transfer_call');
  late final int Function(int, ffi.Pointer<ffi.Int8>) _startAttendedXfer =
      _lib.lookupFunction<
          _EngineStartAttendedXferC,
          int Function(
              int, ffi.Pointer<ffi.Int8>)>('engine_start_attended_xfer');
  late final int Function(int, int) _completeXfer =
      _lib.lookupFunction<_EngineCompleteXferC, int Function(int, int)>(
          'engine_complete_xfer');
  late final int Function(int, int) _mergeConference =
      _lib.lookupFunction<_EngineMergeConferenceC, int Function(int, int)>(
          'engine_merge_conference');
  late final int Function(ffi.Pointer<ffi.Int8>) _startRecording =
      _lib.lookupFunction<_EngineStartRecordingC,
          int Function(ffi.Pointer<ffi.Int8>)>('engine_start_recording');
  late final int Function() _stopRecording =
      _lib.lookupFunction<_EngineStopRecordingC, int Function()>(
          'engine_stop_recording');
  late final int Function() _isRecording =
      _lib.lookupFunction<_EngineIsRecordingC, int Function()>(
          'engine_is_recording');
  late final int Function(ffi.Pointer<ffi.Int8>, ffi.Pointer<ffi.Int8>)
      _sendCommand = _lib.lookupFunction<
          _EngineSendCommandC,
          int Function(ffi.Pointer<ffi.Int8>,
              ffi.Pointer<ffi.Int8>)>('engine_send_command');
  late final void Function(
          ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>>)
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
      throw UnsupportedError(
          'This scaffold currently targets Windows desktop.');
    }
    final lib = ffi.DynamicLibrary.open('voip_core.dll');
    return VoipEngine._(lib);
  }

  int init(String userAgent) {
    final ptr = _allocCString(userAgent);
    try {
      return _init(ptr);
    } finally {
      _freeNative(ptr);
    }
  }

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

  /// Delete an account profile and remove it from the engine.
  /// Returns 0 on success, non-zero on error.
  int deleteAccount(String accountId) {
    return sendCommand('AccountDeleteProfile', '{"uuid": "$accountId"}');
  }

  /// Make an outgoing call using a specific account.
  /// [accountId] is the account UUID to use.
  /// [number] is the destination SIP URI or phone number.
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

  /// Export account profile configuration.
  /// Returns 0 on success, non-zero on error.
  int exportProfile(String accountId) {
    final ptr = _allocCString(accountId);
    try {
      return _exportProfile(ptr);
    } finally {
      _freeNative(ptr);
    }
  }

  /// Import account profile configuration.
  /// Returns 0 on success, non-zero on error.
  int importProfile(String configJson) {
    final ptr = _allocCString(configJson);
    try {
      return _importProfile(ptr);
    } finally {
      _freeNative(ptr);
    }
  }

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

  /// Set the active log level filter.
  int setLogLevel(String level) {
    final ptr = _allocCString(level);
    try {
      return _setLogLevel(ptr);
    } finally {
      _freeNative(ptr);
    }
  }

  /// Request all buffered log entries.
  int getLogBuffer() => _getLogBuffer();

  /// Send DTMF digits on the active call.
  int sendDtmf(String digits) {
    final ptr = _allocCString(digits);
    try {
      return _sendDtmf(ptr);
    } finally {
      _freeNative(ptr);
    }
  }

  /// Play DTMF tones locally.
  int playDtmf(String digits) {
    final ptr = _allocCString(digits);
    try {
      return _playDtmf(ptr);
    } finally {
      _freeNative(ptr);
    }
  }

  /// Initiate blind transfer of the active call.
  /// [callId] is the call to transfer.
  /// [destUri] is the destination SIP URI to transfer the call to.
  /// Returns 0 on success, non-zero on error.
  int transferCall(int callId, String destUri) {
    final ptr = _allocCString(destUri);
    try {
      return _transferCall(callId, ptr);
    } finally {
      _freeNative(ptr);
    }
  }

  /// Start attended (consultative) transfer.
  /// Puts current call on hold and initiates a consultation call.
  /// [callId] is the call to put on hold.
  /// [destUri] is the destination SIP URI to consult with.
  /// Returns new consultation call ID on success, or negative error code.
  int startAttendedXfer(int callId, String destUri) {
    final ptr = _allocCString(destUri);
    try {
      return _startAttendedXfer(callId, ptr);
    } finally {
      _freeNative(ptr);
    }
  }

  /// Complete an attended transfer.
  /// [callAId] is the original call (on hold).
  /// [callBId] is the consultation call ID.
  /// Returns 0 on success, non-zero on error.
  int completeXfer(int callAId, int callBId) {
    return _completeXfer(callAId, callBId);
  }

  /// Merge two calls into a 3-way conference.
  /// [callAId] is the first call.
  /// [callBId] is the second call.
  /// Returns 0 on success, non-zero on error.
  int mergeConference(int callAId, int callBId) {
    return _mergeConference(callAId, callBId);
  }

  /// Start recording the current active call.
  /// [filePath] is the full path to the output WAV file.
  /// Returns 0 on success, non-zero on error.
  int startRecording(String filePath) {
    final ptr = _allocCString(filePath);
    try {
      return _startRecording(ptr);
    } finally {
      _freeNative(ptr);
    }
  }

  /// Stop recording the current active call.
  /// Returns 0 on success, non-zero on error.
  int stopRecording() {
    return _stopRecording();
  }

  /// Check if the current call is being recorded.
  /// Returns 1 if recording, 0 if not.
  int isRecording() {
    return _isRecording();
  }

  /// Send a structured command to the engine as JSON.
  /// [type] is the command name, [payloadJson] is the parameters.
  int sendCommand(String type, String payloadJson) {
    final typePtr = _allocCString(type);
    final payloadPtr = _allocCString(payloadJson);
    try {
      return _sendCommand(typePtr, payloadPtr);
    } finally {
      _freeNative(typePtr);
      _freeNative(payloadPtr);
    }
  }

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
          codePoint = 0x10000 + (codePoint - 0xD800) * 0x400 + (low - 0xDC00);
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
    final ptr = ffi_alloc.calloc
        .allocate<ffi.Int8>(ffi.sizeOf<ffi.Int8>() * bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      (ptr + i).value = bytes[i];
    }
    return ptr;
  }

  void _freeNative(ffi.Pointer<ffi.Int8> ptr) {
    ffi_alloc.calloc.free(ptr);
  }
}

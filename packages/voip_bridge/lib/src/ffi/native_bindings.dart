import 'dart:ffi' as ffi;
import 'dart:io';

typedef EventCallbackNative =
    ffi.Void Function(ffi.Int32 eventId, ffi.Pointer<ffi.Char> payload);

typedef EventCallbackDart =
    void Function(int eventId, ffi.Pointer<ffi.Char> payload);

class NativeBindings {
  NativeBindings._(ffi.DynamicLibrary library)
    : init = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('voip_core_init'),
      shutdown = library.lookupFunction<ffi.Int32 Function(), int Function()>(
        'voip_core_shutdown',
      ),
      setEventCallback = library
          .lookupFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.NativeFunction<EventCallbackNative>>,
            ),
            int Function(ffi.Pointer<ffi.NativeFunction<EventCallbackNative>>)
          >('voip_core_set_event_callback'),
      accountUpsert = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('voip_account_upsert'),
      accountRemove = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('voip_account_remove'),
      accountRegister = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('voip_account_register'),
      accountUnregister = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('voip_account_unregister'),
      callStart = library
          .lookupFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Int32,
            ),
            int Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              int,
            )
          >('voip_call_start'),
      callAnswer = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('voip_call_answer'),
      callReject = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('voip_call_reject'),
      callHangup = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>)
          >('voip_call_hangup'),
      callSetMute = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Int32),
            int Function(ffi.Pointer<ffi.Char>, int)
          >('voip_call_set_mute'),
      callSetHold = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Int32),
            int Function(ffi.Pointer<ffi.Char>, int)
          >('voip_call_set_hold'),
      callSendDtmf = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)
          >('voip_call_send_dtmf'),
      debugSimulateIncoming = library
          .lookupFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
            ),
            int Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
            )
          >('voip_debug_simulate_incoming'),
      callTransferBlind = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)
          >('voip_call_transfer_blind'),
      callTransferAttendedStart = library
          .lookupFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Int32,
            ),
            int Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              int,
            )
          >('voip_call_transfer_attended_start'),
      callTransferAttendedComplete = library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>),
            int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)
          >('voip_call_transfer_attended_complete'),
      diagExport = library
          .lookupFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Int32,
            ),
            int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>, int)
          >('voip_diag_export'),
      audioSetRoute = library
          .lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>(
            'voip_audio_set_route',
          );

  factory NativeBindings.load() => NativeBindings._(_openLibrary());

  final int Function(ffi.Pointer<ffi.Char>) init;
  final int Function() shutdown;
  final int Function(ffi.Pointer<ffi.NativeFunction<EventCallbackNative>>)
  setEventCallback;
  final int Function(ffi.Pointer<ffi.Char>) accountUpsert;
  final int Function(ffi.Pointer<ffi.Char>) accountRemove;
  final int Function(ffi.Pointer<ffi.Char>) accountRegister;
  final int Function(ffi.Pointer<ffi.Char>) accountUnregister;
  final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    int,
  )
  callStart;
  final int Function(ffi.Pointer<ffi.Char>) callAnswer;
  final int Function(ffi.Pointer<ffi.Char>) callReject;
  final int Function(ffi.Pointer<ffi.Char>) callHangup;
  final int Function(ffi.Pointer<ffi.Char>, int) callSetMute;
  final int Function(ffi.Pointer<ffi.Char>, int) callSetHold;
  final int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>) callSendDtmf;
  final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  )
  debugSimulateIncoming;
  final int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)
  callTransferBlind;
  final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    int,
  )
  callTransferAttendedStart;
  final int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)
  callTransferAttendedComplete;
  final int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>, int)
  diagExport;
  final int Function(int) audioSetRoute;

  static ffi.DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('voip_core.dll');
    }
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libvoip_core.so');
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return ffi.DynamicLibrary.process();
    }
    throw UnsupportedError('Unsupported platform for native PacketDial bridge');
  }
}

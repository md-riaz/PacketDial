import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:io';

typedef EngineInitC = ffi.Int32 Function(ffi.Pointer<Utf8> user_agent);
typedef EngineInitDart = int Function(ffi.Pointer<Utf8> user_agent);

typedef EngineShutdownC = ffi.Int32 Function();
typedef EngineShutdownDart = int Function();

typedef EngineSetEventCallbackC =
    ffi.Void Function(
      ffi.Pointer<
        ffi.NativeFunction<ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>
      >,
    );
typedef EngineSetEventCallbackDart =
    void Function(
      ffi.Pointer<
        ffi.NativeFunction<ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)>
      >,
    );

typedef EngineSendCommandC =
    ffi.Int32 Function(ffi.Pointer<Utf8> cmd_type, ffi.Pointer<Utf8> payload);
typedef EngineSendCommandDart =
    int Function(ffi.Pointer<Utf8> cmd_type, ffi.Pointer<Utf8> payload);

void eventCallback(int eventId, ffi.Pointer<ffi.Int8> jsonDataPtr) {
  if (jsonDataPtr.address == 0) return;
  final jsonStr = jsonDataPtr.cast<Utf8>().toDartString();
  print('[EVENT $eventId] $jsonStr');
}

void main() async {
  print('Loading voip_core.dll...');
  final lib = ffi.DynamicLibrary.open(
    'c:\\Users\\vm_user\\Downloads\\PacketDial\\dist\\extracted\\voip_core.dll',
  );

  final engineInit = lib.lookupFunction<EngineInitC, EngineInitDart>(
    'engine_init',
  );
  final engineSetCallback = lib
      .lookupFunction<EngineSetEventCallbackC, EngineSetEventCallbackDart>(
        'engine_set_event_callback',
      );
  final engineSendCommand = lib
      .lookupFunction<EngineSendCommandC, EngineSendCommandDart>(
        'engine_send_command',
      );
  final engineShutdown = lib
      .lookupFunction<EngineShutdownC, EngineShutdownDart>('engine_shutdown');

  print('Initializing engine...');
  engineInit("TestAgent".toNativeUtf8());

  final nativeCallable =
      ffi.NativeCallable<
        ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>)
      >.listener(eventCallback);
  engineSetCallback(nativeCallable.nativeFunction);

  print('Registering Account...');
  final upsertPayload =
      '{"uuid": "test-acct", "server": "cpx.alphapbx.net", "username": "127", "password": "dummy_password", "transport": "udp", "tls_enabled": false, "srtp_enabled": false}'
          .toNativeUtf8();
  engineSendCommand("AccountUpsert".toNativeUtf8(), upsertPayload);

  final registerPayload = '{"uuid": "test-acct"}'.toNativeUtf8();
  engineSendCommand("AccountRegister".toNativeUtf8(), registerPayload);

  // Wait a moment for registration
  await Future.delayed(Duration(seconds: 2));

  print('Starting Call...');
  final callPayload =
      '{"account_id": "test-acct", "uri": "sip:127@cpx.alphapbx.net:8090"}'
          .toNativeUtf8();
  engineSendCommand("CallStart".toNativeUtf8(), callPayload);

  // Wait to capture logs
  await Future.delayed(Duration(seconds: 2));

  engineShutdown();
  nativeCallable.close();
}

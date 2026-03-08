import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'ffi/engine.dart';

typedef NativeCallback = ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>);

void main() async {
  // Test with realm specified
  const server = 'pbx.dev.ipbx.link:5060';
  const user = '102';
  const pass = '102';
  const domain = 'pbx.dev.ipbx.link';
  const uuid = 'test-cli-102';
  const auth_user = '102';
  const realm = 'pbx.dev.ipbx.link'; // Explicit realm

  print('================================================');
  print('    SIP TEST CLI - NO STUN DIAGNOSTIC (v6)      ');
  print('================================================');

  try {
    final engine = VoipEngine.load();

    void _onEvent(int id, ffi.Pointer<ffi.Int8> data) {
      if (data == ffi.nullptr) {
        print('[EVENT] nullptr data');
        return;
      }
      try {
        final List<int> bytes = [];
        int i = 0;
        while (i < 1000) { // Safety limit
          final byte = data.elementAt(i).value;
          if (byte == 0) break;
          bytes.add(byte);
          i++;
        }
        if (bytes.isEmpty) {
          print('[EVENT] empty data');
          return;
        }
        final raw = utf8.decode(bytes, allowMalformed: true);
        print('[EVENT RAW] $raw');
        final map = jsonDecode(raw);
        final type = map['type'] ?? 'Unknown';

        print('[EVENT] $type: ${map['payload']}');
        
        if (type == 'SipMessageCaptured') {
          print('\n[SIP ${map['payload']['direction'].toUpperCase()}]');
          print(map['payload']['raw']);
        } else if (type == 'RegistrationStateChanged') {
          print(
              '\n[STATUS] ${map['payload']['state']}: ${map['payload']['reason']}');
        }
      } catch (e) {
        print('[EVENT ERROR] $e');
      }
    }

    final nativeCallable =
        ffi.NativeCallable<NativeCallback>.listener(_onEvent);
    engine.setEventCallback(nativeCallable.nativeFunction);

    print('>>> Initializing Engine (Log: Debug)...');
    engine.init('PacketDial-CLI-v6');
    await Future.delayed(const Duration(milliseconds: 500)); // Wait for PJSIP to fully init
    engine.sendCommand('SetLogLevel', jsonEncode({'level': 'debug'}));

    print('>>> AccountUpsert (pbx.dev.ipbx.link:5060, TCP, no TLS)...');
    final payload = {
      'uuid': uuid,
      'username': user,
      'password': pass,
      'auth_username': auth_user,
      'server': server,
      'domain': domain,
      'transport': 'tcp',
      'tls_enabled': false,
      'stun_server': '',
    };

    print('Payload: ${jsonEncode(payload)}');
    engine.sendCommand('AccountUpsert', jsonEncode(payload));

    print('>>> Registering...');
    engine.sendCommand('AccountRegister', jsonEncode({'uuid': uuid}));

    print('>>> Waiting for registration (30 seconds)...');
    await Future.delayed(const Duration(seconds: 30));

    print('\n>>> Shutting down.');
    engine.shutdown();
    nativeCallable.close();
  } catch (e) {
    print('!!! ERROR: $e');
  }
}

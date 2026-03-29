import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'ffi/engine.dart';

typedef NativeCallback = ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>);

void main() async {
  // Test with realm specified
  const server = 'pbx.dev.ipbx.link:5060';
  const user = '102';
  const pass = '102';
  const domain = 'pbx.dev.ipbx.link';
  const uuid = 'test-cli-102';
  const authUser = '102';

  stdout.writeln('================================================');
  stdout.writeln('    SIP TEST CLI - NO STUN DIAGNOSTIC (v6)      ');
  stdout.writeln('================================================');

  try {
    final engine = VoipEngine.load();

    void onEvent(int id, ffi.Pointer<ffi.Int8> data) {
      if (data == ffi.nullptr) {
        stdout.writeln('[EVENT] nullptr data');
        return;
      }
      try {
        final List<int> bytes = [];
        int i = 0;
        while (i < 1000) {
          // Safety limit
          final byte = (data + i).value;
          if (byte == 0) break;
          bytes.add(byte);
          i++;
        }
        if (bytes.isEmpty) {
          stdout.writeln('[EVENT] empty data');
          return;
        }
        final raw = utf8.decode(bytes, allowMalformed: true);
        stdout.writeln('[EVENT RAW] $raw');
        final map = jsonDecode(raw);
        final type = map['type'] ?? 'Unknown';

        stdout.writeln('[EVENT] $type: ${map['payload']}');

        if (type == 'SipMessageCaptured') {
          stdout
              .writeln('\n[SIP ${map['payload']['direction'].toUpperCase()}]');
          stdout.writeln(map['payload']['raw']);
        } else if (type == 'RegistrationStateChanged') {
          stdout.writeln(
            '\n[STATUS] ${map['payload']['state']}: ${map['payload']['reason']}',
          );
        }
      } catch (e) {
        stdout.writeln('[EVENT ERROR] $e');
      }
    }

    final nativeCallable = ffi.NativeCallable<NativeCallback>.listener(onEvent);
    engine.setEventCallback(nativeCallable.nativeFunction);

    stdout.writeln('>>> Initializing Engine (Log: Debug)...');
    engine.init('PacketDial-CLI-v6');
    await Future.delayed(
        const Duration(milliseconds: 500)); // Wait for PJSIP to fully init
    engine.sendCommand('SetLogLevel', jsonEncode({'level': 'debug'}));

    stdout
        .writeln('>>> AccountUpsert (pbx.dev.ipbx.link:5060, TCP, no TLS)...');
    final payload = {
      'uuid': uuid,
      'username': user,
      'password': pass,
      'auth_username': authUser,
      'server': server,
      'domain': domain,
      'transport': 'tcp',
      'tls_enabled': false,
      'stun_server': '',
    };

    stdout.writeln('Payload: ${jsonEncode(payload)}');
    engine.sendCommand('AccountUpsert', jsonEncode(payload));

    stdout.writeln('>>> Registering...');
    engine.sendCommand('AccountRegister', jsonEncode({'uuid': uuid}));

    stdout.writeln('>>> Waiting for registration (30 seconds)...');
    await Future.delayed(const Duration(seconds: 30));

    stdout.writeln('\n>>> Shutting down.');
    engine.shutdown();
    nativeCallable.close();
  } catch (e) {
    stdout.writeln('!!! ERROR: $e');
  }
}

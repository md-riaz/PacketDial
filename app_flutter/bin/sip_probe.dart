import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:voip_softphone/ffi/engine.dart';

typedef NativeCallback = ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Int8>);

void main(List<String> args) async {
  final parsed = _ProbeArgs.parse(args);
  if (parsed == null) {
    _printUsage();
    exitCode = 2;
    return;
  }

  final engine = VoipEngine.load();
  final regCompleters = <String, Completer<_RegResult>>{};
  final callCompleter = Completer<_CallResult>();
  var waitingForCallState = false;
  final logBufferCompleter = Completer<void>();
  final logEntries = <Map<String, dynamic>>[];
  final uuid = 'probe-${DateTime.now().millisecondsSinceEpoch}';
  regCompleters[uuid] = Completer<_RegResult>();

  void onEvent(int eventId, ffi.Pointer<ffi.Int8> dataPtr) {
    final raw = _readCString(dataPtr);
    if (raw.isEmpty) return;

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      stdout.writeln('[probe] event_id=$eventId raw=$raw');
      return;
    }

    if (eventId == EngineEventId.engineLog) {
      final level = payload['level'] ?? '?';
      final message = payload['message'] ?? '';
      stdout.writeln('[engine:$level] $message');
      return;
    }

    if (eventId == EngineEventId.logBufferResult) {
      final entries = (payload['entries'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      logEntries
        ..clear()
        ..addAll(entries);
      if (!logBufferCompleter.isCompleted) {
        logBufferCompleter.complete();
      }
      return;
    }

    if (eventId == EngineEventId.registrationStateChanged) {
      final accountId = payload['account_id'] as String? ?? '';
      final state = payload['state'] as String? ?? '';
      final reason = payload['reason'] as String? ?? '';
      stdout.writeln('[probe] registration state: $state reason="$reason"');
      final completer = regCompleters[accountId];
      if (completer == null || completer.isCompleted) return;
      if (state == 'Registered') {
        completer.complete(const _RegResult(success: true));
      } else if (state == 'Failed') {
        completer.complete(_RegResult(success: false, reason: reason));
      }
    }

    if (eventId == EngineEventId.callStateChanged) {
      if (!waitingForCallState || callCompleter.isCompleted) return;
      final accountId = payload['account_id'] as String? ?? '';
      if (accountId != uuid) return;
      final state = payload['state'] as String? ?? '';
      final uri = payload['uri'] as String? ?? '';
      stdout.writeln('[probe] call state: $state uri="$uri"');
      if (state == 'Ringing' || state == 'InCall' || state == 'Ended') {
        callCompleter.complete(_CallResult(state: state, uri: uri));
      }
    }
  }

  final nativeCallback = ffi.NativeCallable<NativeCallback>.listener(onEvent);
  engine.setEventCallback(nativeCallback.nativeFunction);

  try {
    final initRc = engine.init('PacketDial-sip_probe');
    stdout.writeln('[probe] engine_init rc=$initRc');
    if (initRc != 0) {
      exitCode = 1;
      return;
    }

    final logRc = engine.sendCommand('SetLogLevel', '{"level":"Debug"}');
    stdout.writeln('[probe] SetLogLevel rc=$logRc');

    final payload = {
      'uuid': uuid,
      'account_name': 'Probe',
      'display_name': parsed.username,
      'username': parsed.username,
      'auth_username': parsed.username,
      'password': parsed.password,
      'server': parsed.server,
      'domain': parsed.domain,
      'sip_proxy': parsed.proxy,
      'transport': parsed.transport,
      'stun_server': '',
      'turn_server': '',
      'tls_enabled': parsed.transport == 'tls',
      'srtp_enabled': false,
    };
    final safePayload = Map<String, dynamic>.from(payload)
      ..['password'] = '***';
    stdout.writeln('[probe] AccountUpsert payload=${jsonEncode(safePayload)}');
    final upsertRc = engine.sendCommand('AccountUpsert', jsonEncode(payload));
    stdout.writeln('[probe] AccountUpsert rc=$upsertRc');
    if (upsertRc != 0) {
      exitCode = 1;
      return;
    }

    final registerRc =
        engine.sendCommand('AccountRegister', jsonEncode({'uuid': uuid}));
    stdout.writeln('[probe] AccountRegister rc=$registerRc');
    if (registerRc != 0) {
      exitCode = 1;
      return;
    }

    final result = await regCompleters[uuid]!
        .future
        .timeout(const Duration(seconds: 20), onTimeout: () {
      return const _RegResult(success: false, reason: 'timeout');
    });

    if (result.success) {
      stdout.writeln('[probe] RESULT=SUCCESS');
      exitCode = 0;

      if (parsed.multiTwo) {
        final uuid2 = '$uuid-second';
        regCompleters[uuid2] = Completer<_RegResult>();
        final payload2 = {
          'uuid': uuid2,
          'account_name': 'Probe 2',
          'display_name': '${parsed.username}-2',
          'username': parsed.username,
          'auth_username': parsed.username,
          'password': parsed.password,
          'server': parsed.server,
          'domain': parsed.domain,
          'sip_proxy': parsed.proxy,
          'transport': parsed.transport,
          'stun_server': '',
          'turn_server': '',
          'tls_enabled': parsed.transport == 'tls',
          'srtp_enabled': false,
        };
        stdout.writeln(
            '[probe] multi-two: AccountUpsert(2) rc=${engine.sendCommand('AccountUpsert', jsonEncode(payload2))}');
        stdout.writeln(
            '[probe] multi-two: AccountRegister(2) rc=${engine.sendCommand('AccountRegister', jsonEncode({
                      'uuid': uuid2
                    }))}');
        final result2 = await regCompleters[uuid2]!.future.timeout(
              const Duration(seconds: 20),
              onTimeout: () =>
                  const _RegResult(success: false, reason: 'timeout'),
            );
        stdout.writeln(
            '[probe] multi-two result: success=${result2.success} reason="${result2.reason}"');
        if (!result2.success) {
          exitCode = 1;
        }
      }

      if (parsed.dial.isNotEmpty) {
        waitingForCallState = true;
        final callRc = engine.sendCommand(
          'CallStart',
          jsonEncode({
            'account_id': uuid,
            'uri': parsed.dial,
          }),
        );
        stdout.writeln('[probe] CallStart target="${parsed.dial}" rc=$callRc');
        if (callRc != 0) {
          stdout.writeln('[probe] CALL_RESULT=FAILED rc=$callRc');
          final getLogsRc = engine.sendCommand('GetLogBuffer', '{}');
          stdout.writeln('[probe] GetLogBuffer rc=$getLogsRc');
          if (getLogsRc == 0) {
            await logBufferCompleter.future
                .timeout(const Duration(seconds: 2), onTimeout: () {});
            if (logEntries.isNotEmpty) {
              stdout.writeln('[probe] recent engine logs:');
              for (final entry in logEntries
                  .skip(logEntries.length > 12 ? logEntries.length - 12 : 0)) {
                final level = entry['level'] ?? '?';
                final message = entry['message'] ?? '';
                stdout.writeln('  [$level] $message');
              }
            }
          }
          exitCode = 1;
        } else {
          final callResult = await callCompleter.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () => const _CallResult(state: 'Timeout', uri: ''),
          );
          stdout.writeln(
              '[probe] CALL_RESULT state=${callResult.state} uri="${callResult.uri}"');
          if (callResult.state == 'Timeout') {
            exitCode = 1;
          }
          final hangupRc = engine.sendCommand('CallHangup', '{}');
          stdout.writeln('[probe] CallHangup rc=$hangupRc');
        }
      }
    } else {
      stdout.writeln('[probe] RESULT=FAILED reason="${result.reason}"');
      exitCode = 1;
    }
  } finally {
    final unregRc =
        engine.sendCommand('AccountUnregister', jsonEncode({'uuid': uuid}));
    final delRc =
        engine.sendCommand('AccountDeleteProfile', jsonEncode({'uuid': uuid}));
    stdout.writeln('[probe] cleanup unregister_rc=$unregRc delete_rc=$delRc');
    if (parsed.multiTwo) {
      final uuid2 = '$uuid-second';
      final unregRc2 =
          engine.sendCommand('AccountUnregister', jsonEncode({'uuid': uuid2}));
      final delRc2 = engine.sendCommand(
          'AccountDeleteProfile', jsonEncode({'uuid': uuid2}));
      stdout.writeln(
          '[probe] cleanup(second) unregister_rc=$unregRc2 delete_rc=$delRc2');
    }

    engine.setEventCallback(ffi.nullptr);
    nativeCallback.close();
    final shutdownRc = engine.shutdown();
    stdout.writeln('[probe] engine_shutdown rc=$shutdownRc');
  }
}

String _readCString(ffi.Pointer<ffi.Int8> ptr) {
  if (ptr == ffi.nullptr) return '';
  final bytes = <int>[];
  var i = 0;
  while (i < 8192) {
    final v = (ptr + i).value;
    if (v == 0) break;
    bytes.add(v);
    i++;
  }
  return utf8.decode(bytes, allowMalformed: true);
}

class _RegResult {
  final bool success;
  final String reason;

  const _RegResult({required this.success, this.reason = ''});
}

class _CallResult {
  final String state;
  final String uri;

  const _CallResult({required this.state, required this.uri});
}

class _ProbeArgs {
  final String server;
  final String username;
  final String password;
  final String domain;
  final String proxy;
  final String transport;
  final String dial;
  final bool multiTwo;

  const _ProbeArgs({
    required this.server,
    required this.username,
    required this.password,
    required this.domain,
    required this.proxy,
    required this.transport,
    required this.dial,
    required this.multiTwo,
  });

  static _ProbeArgs? parse(List<String> args) {
    String? server;
    String? username;
    String? password;
    String? domain;
    String proxy = '';
    String transport = 'udp';
    String dial = '';
    bool multiTwo = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--server':
          if (i + 1 < args.length) server = args[++i];
          break;
        case '--username':
          if (i + 1 < args.length) username = args[++i];
          break;
        case '--password':
          if (i + 1 < args.length) password = args[++i];
          break;
        case '--domain':
          if (i + 1 < args.length) domain = args[++i];
          break;
        case '--proxy':
          if (i + 1 < args.length) proxy = args[++i];
          break;
        case '--transport':
          if (i + 1 < args.length) {
            transport = args[++i].toLowerCase();
          }
          break;
        case '--dial':
          if (i + 1 < args.length) dial = args[++i];
          break;
        case '--multi-two':
          multiTwo = true;
          break;
      }
    }

    if (server == null || username == null || password == null) {
      return null;
    }

    if (transport != 'udp' && transport != 'tcp' && transport != 'tls') {
      return null;
    }

    return _ProbeArgs(
      server: server,
      username: username,
      password: password,
      domain: domain ?? server.split(':').first,
      proxy: proxy,
      transport: transport,
      dial: dial,
      multiTwo: multiTwo,
    );
  }
}

void _printUsage() {
  stdout.writeln(
      'Usage: dart run bin/sip_probe.dart --server <host[:port]> --username <user> --password <pass> [--domain <domain>] [--proxy <sip:...>] [--transport udp|tcp|tls] [--dial <target>] [--multi-two]');
}

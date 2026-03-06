import 'package:flutter/foundation.dart';
import 'engine_channel.dart';
import '../models/account.dart';
import '../models/call.dart';

class CliService {
  CliService._();
  static final CliService instance = CliService._();

  /// Parse and handle CLI arguments.
  Future<void> handleArgs(List<String> args) async {
    if (args.isEmpty) return;

    debugPrint('[CliService] Handling args: $args');

    for (int i = 0; i < args.length; i++) {
      final arg = args[i].toLowerCase();

      switch (arg) {
        case '-call':
          if (i + 1 < args.length) {
            final number = args[i + 1];
            _makeCall(number);
            i++; // skip next arg
          }
          break;
        case '-answer':
          _answerCall();
          break;
        case '-hangup':
          _hangupCall();
          break;
        case '-setstatus':
          if (i + 1 < args.length) {
            final status = args[i + 1];
            _setStatus(status);
            i++;
          }
          break;
      }
    }
  }

  void _makeCall(String number) {
    // Wait for engine to be ready
    if (!EngineChannel.instance.engineReady) {
      debugPrint('[CliService] Engine not ready, delaying call to $number');
      Future.delayed(const Duration(seconds: 2), () => _makeCall(number));
      return;
    }

    // Try to find a registered account
    final registeredAccount = EngineChannel.instance.accounts.values.firstWhere(
      (a) => a.registrationState == RegistrationState.registered,
      orElse: () => EngineChannel.instance.accounts.values.first,
    );

    debugPrint(
        '[CliService] Placing call to $number via ${registeredAccount.uuid}');
    EngineChannel.instance.engine.makeCall(registeredAccount.uuid, number);
  }

  void _answerCall() {
    if (!EngineChannel.instance.engineReady) return;
    final call = EngineChannel.instance.activeCall;
    if (call != null &&
        call.state == CallState.ringing &&
        call.direction == CallDirection.incoming) {
      debugPrint('[CliService] Answering active call');
      EngineChannel.instance.engine.answerCall();
    }
  }

  void _hangupCall() {
    if (!EngineChannel.instance.engineReady) return;
    final call = EngineChannel.instance.activeCall;
    if (call != null) {
      debugPrint('[CliService] Hanging up call ${call.callId}');
      EngineChannel.instance.engine.hangup();
    }
  }

  void _setStatus(String status) {
    // This is a placeholder since the engine might not support setting presence yet
    // but we can log it or update local status.
    debugPrint(
        '[CliService] Setting status to $status (not fully implemented in engine)');
  }
}

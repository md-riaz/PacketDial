import 'package:flutter_test/flutter_test.dart';
import 'package:voip_softphone/models/account.dart';
import 'package:voip_softphone/models/call.dart';

void main() {
  group('RegistrationState', () {
    test('fromString maps Rust variant names correctly', () {
      expect(RegistrationState.fromString('Registered'),
          RegistrationState.registered);
      expect(RegistrationState.fromString('Registering'),
          RegistrationState.registering);
      expect(
          RegistrationState.fromString('Failed'), RegistrationState.failed);
      expect(RegistrationState.fromString('Unregistered'),
          RegistrationState.unregistered);
      // Unknown strings default to unregistered
      expect(RegistrationState.fromString(''),
          RegistrationState.unregistered);
    });

    test('label produces human-readable text', () {
      expect(RegistrationState.registered.label, 'Registered');
      expect(RegistrationState.failed.label, 'Failed');
    });
  });

  group('CallState', () {
    test('fromString maps Rust variant names correctly', () {
      expect(CallState.fromString('Ringing'), CallState.ringing);
      expect(CallState.fromString('InCall'), CallState.inCall);
      expect(CallState.fromString('OnHold'), CallState.onHold);
      expect(CallState.fromString('Ended'), CallState.ended);
      // Unknown strings default to ringing
      expect(CallState.fromString(''), CallState.ringing);
    });

    test('label produces human-readable text', () {
      expect(CallState.inCall.label, 'In Call');
      expect(CallState.ended.label, 'Ended');
    });
  });

  group('CallDirection', () {
    test('fromString maps correctly', () {
      expect(
          CallDirection.fromString('Incoming'), CallDirection.incoming);
      expect(
          CallDirection.fromString('Outgoing'), CallDirection.outgoing);
      expect(CallDirection.fromString(''), CallDirection.outgoing);
    });
  });

  group('Account', () {
    test('copyWith preserves id and updates fields', () {
      const original = Account(
        id: 'acc1',
        displayName: 'Alice',
        server: 'sip.example.com',
        username: 'alice',
        password: 'secret',
      );
      final updated = original.copyWith(
        registrationState: RegistrationState.registered,
      );
      expect(updated.id, 'acc1');
      expect(updated.displayName, 'Alice');
      expect(updated.registrationState, RegistrationState.registered);
    });

    test('default values', () {
      const acct = Account(
        id: 'test',
        displayName: 'Test',
        server: 'sip.test',
        username: 'u',
        password: 'p',
      );
      expect(acct.transport, 'udp');
      expect(acct.tlsEnabled, false);
      expect(acct.srtpEnabled, false);
      expect(acct.registrationState, RegistrationState.unregistered);
    });
  });

  group('ActiveCall', () {
    test('copyWith updates muted and onHold', () {
      const call = ActiveCall(
        callId: 1,
        accountId: 'acc1',
        uri: 'sip:bob@example.com',
        direction: CallDirection.outgoing,
        state: CallState.inCall,
        muted: false,
        onHold: false,
      );
      final muted = call.copyWith(muted: true);
      expect(muted.muted, true);
      expect(muted.onHold, false);
      expect(muted.callId, 1);
    });
  });
}

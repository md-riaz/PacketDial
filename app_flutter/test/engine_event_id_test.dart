import 'package:flutter_test/flutter_test.dart';
import 'package:voip_softphone/ffi/engine.dart';

void main() {
  group('EngineEventId', () {
    test('event IDs match Rust EngineEventId enum values', () {
      expect(EngineEventId.registered, 1);
      expect(EngineEventId.registrationFailed, 2);
      expect(EngineEventId.incomingCall, 3);
      expect(EngineEventId.callConnected, 4);
      expect(EngineEventId.callTerminated, 5);
      expect(EngineEventId.errorOccurred, 6);
    });

    test('event IDs are distinct', () {
      final ids = {
        EngineEventId.registered,
        EngineEventId.registrationFailed,
        EngineEventId.incomingCall,
        EngineEventId.callConnected,
        EngineEventId.callTerminated,
        EngineEventId.errorOccurred,
      };
      expect(ids.length, 6, reason: 'All event IDs must be unique');
    });
  });
}

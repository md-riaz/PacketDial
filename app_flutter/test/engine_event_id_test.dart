import 'package:flutter_test/flutter_test.dart';
import 'package:voip_softphone/ffi/engine.dart';

void main() {
  group('EngineEventId', () {
    test('event IDs match Rust EngineEventId enum values', () {
      expect(EngineEventId.engineReady, 1);
      expect(EngineEventId.registrationStateChanged, 2);
      expect(EngineEventId.callStateChanged, 3);
      expect(EngineEventId.mediaStatsUpdated, 4);
      expect(EngineEventId.audioDeviceList, 5);
      expect(EngineEventId.audioDevicesSet, 6);
      expect(EngineEventId.callHistoryResult, 7);
      expect(EngineEventId.sipMessageCaptured, 8);
      expect(EngineEventId.diagBundleReady, 9);
      expect(EngineEventId.accountSecurityUpdated, 10);
      expect(EngineEventId.credStored, 11);
      expect(EngineEventId.credRetrieved, 12);
      expect(EngineEventId.enginePong, 13);
      expect(EngineEventId.logLevelSet, 14);
      expect(EngineEventId.logBufferResult, 15);
      expect(EngineEventId.engineLog, 16);
    });

    test('event IDs are distinct', () {
      final ids = {
        EngineEventId.engineReady,
        EngineEventId.registrationStateChanged,
        EngineEventId.callStateChanged,
        EngineEventId.mediaStatsUpdated,
        EngineEventId.audioDeviceList,
        EngineEventId.audioDevicesSet,
        EngineEventId.callHistoryResult,
        EngineEventId.sipMessageCaptured,
        EngineEventId.diagBundleReady,
        EngineEventId.accountSecurityUpdated,
        EngineEventId.credStored,
        EngineEventId.credRetrieved,
        EngineEventId.enginePong,
        EngineEventId.logLevelSet,
        EngineEventId.logBufferResult,
        EngineEventId.engineLog,
      };
      expect(ids.length, 16, reason: 'All event IDs must be unique');
    });
  });
}

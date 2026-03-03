import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ffi/engine.dart';
import '../core/engine_channel.dart';
import 'dart:convert';

/// Provider for the raw VoipEngine instance.
final engineProvider = Provider<VoipEngine>((ref) {
  return VoipEngine.load();
});

/// Provider for the stream of events coming from the native SIP engine.
final engineEventsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return EngineChannel.instance.eventStream.map((event) {
    try {
      return jsonDecode(event.data) as Map<String, dynamic>;
    } catch (e) {
      return {'type': 'error', 'error': e.toString(), 'raw': event.data};
    }
  });
});

/// Specialized provider for registration state.
final registrationStateProvider = Provider<String>((ref) {
  final events = ref.watch(engineEventsProvider);

  return events.when(
    data: (data) {
      if (data['type'] == 'RegistrationStateChanged') {
        final payload = data['payload'] as Map<String, dynamic>;
        return payload['state'] as String;
      }
      return 'Unknown';
    },
    loading: () => 'Initializing...',
    error: (e, _) => 'Error: $e',
  );
});

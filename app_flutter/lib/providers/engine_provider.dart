import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ffi/engine.dart';
import '../core/engine_channel.dart';
import '../models/call.dart';
import '../models/media_stats.dart';
import '../models/account.dart';

/// Provider for the raw VoipEngine instance.
final engineProvider = Provider<VoipEngine>((ref) {
  return VoipEngine.load();
});

/// Provider for the stream of events coming from the native SIP engine.
final engineEventsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return EngineChannel.instance.eventStream;
});

final activeCallProvider = Provider<ActiveCall?>((ref) {
  ref.watch(engineEventsProvider);
  return EngineChannel.instance.activeCall;
});

final activeCallMediaStatsProvider = Provider<MediaStats?>((ref) {
  ref.watch(engineEventsProvider);
  final call = EngineChannel.instance.activeCall;
  if (call == null) return null;
  return EngineChannel.instance.mediaStats[call.callId];
});

/// Specialized provider for registration state.
final registrationStateProvider = Provider<String>((ref) {
  // We need to watch events AND potentially account changes
  ref.watch(engineEventsProvider);

  final engine = EngineChannel.instance;
  // Get the single selected account's state
  final accounts = engine.accounts.values.toList();
  if (accounts.isEmpty) return 'No Account';

  final activeAccount = accounts.firstWhere(
      (a) => a.registrationState != RegistrationState.unregistered,
      orElse: () => accounts.first);

  String state = activeAccount.registrationState.label;
  if (activeAccount.registrationState == RegistrationState.registered) {
    return 'Registered';
  } else if (activeAccount.registrationState == RegistrationState.failed) {
    return 'Registration Failed: ${activeAccount.failureReason}';
  }
  return state;
});

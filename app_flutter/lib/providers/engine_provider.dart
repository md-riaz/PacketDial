import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ffi/engine.dart';
import '../core/engine_channel.dart';
import '../models/call.dart';
import '../models/media_stats.dart';
import '../models/account.dart';
import '../models/audio_device.dart';

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

/// Provider for the list of available audio devices
final audioDevicesProvider = Provider<List<AudioDevice>>((ref) {
  ref.watch(engineEventsProvider);
  return EngineChannel.instance.audioDevices;
});

/// Provider for the currently active (registered or first) account.
final activeAccountProvider = Provider<Account?>((ref) {
  ref.watch(engineEventsProvider);
  final accounts = EngineChannel.instance.accounts.values.toList();
  if (accounts.isEmpty) return null;

  return accounts.firstWhere(
      (a) => a.registrationState != RegistrationState.unregistered,
      orElse: () => accounts.first);
});

/// Model to store aggregate registration statistics across all accounts.
class RegistrationSummary {
  final int totalRegistered;
  final int totalFailed;
  final int totalRegistering;
  final int totalEnabled;

  const RegistrationSummary({
    this.totalRegistered = 0,
    this.totalFailed = 0,
    this.totalRegistering = 0,
    this.totalEnabled = 0,
  });

  bool get anyActive => totalEnabled > 0;
}

/// Provider for aggregate registration statistics.
final registrationSummaryProvider = Provider<RegistrationSummary>((ref) {
  ref.watch(engineEventsProvider);
  final accounts = EngineChannel.instance.accounts.values.toList();

  int registered = 0;
  int failed = 0;
  int registering = 0;
  int enabled = 0;

  for (final a in accounts) {
    if (a.registrationState != RegistrationState.unregistered) {
      enabled++;
    }
    if (a.registrationState == RegistrationState.registered) {
      registered++;
    } else if (a.registrationState == RegistrationState.failed) {
      failed++;
    } else if (a.registrationState == RegistrationState.registering) {
      registering++;
    }
  }

  return RegistrationSummary(
    totalRegistered: registered,
    totalFailed: failed,
    totalRegistering: registering,
    totalEnabled: enabled,
  );
});

/// Specialized provider for registration status text.
final registrationStateProvider = Provider<String>((ref) {
  final summary = ref.watch(registrationSummaryProvider);
  final activeAccount = ref.watch(activeAccountProvider);

  if (summary.totalEnabled == 0) return 'No Account';

  if (summary.totalEnabled > 1) {
    final parts = <String>[];
    if (summary.totalRegistered > 0) {
      parts.add('${summary.totalRegistered} Registered');
    }
    if (summary.totalFailed > 0) {
      parts.add('${summary.totalFailed} Failed');
    }
    if (summary.totalRegistering > 0 && summary.totalRegistered == 0) {
      parts.add('Registering...');
    }

    if (parts.isEmpty && summary.totalEnabled > 0) {
      return 'Disconnected';
    }
    return parts.join(', ');
  }

  // Single account fallback (existing behavior)
  if (activeAccount == null) return 'No Account';
  if (activeAccount.registrationState == RegistrationState.registered) {
    return 'Registered';
  } else if (activeAccount.registrationState == RegistrationState.failed) {
    return 'Registration Failed: ${activeAccount.failureReason}';
  }
  return activeAccount.registrationState.label;
});

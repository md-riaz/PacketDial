import 'package:voip_bridge/voip_bridge.dart';

import '../models/active_call.dart';
import '../models/diagnostics_bundle.dart';
import '../models/enums.dart';
import '../repositories/history_repository.dart';
import 'call_ledger.dart';
import 'diagnostics_ledger.dart';
import 'log_ledger.dart';
import 'registration_ledger.dart';

class VoipEventRouter {
  VoipEventRouter({
    required RegistrationLedger registrationLedger,
    required CallLedger callLedger,
    required DiagnosticsLedger diagnosticsLedger,
    required LogLedger logLedger,
    required String Function(String accountId) accountLabelForId,
    required void Function(bool engineReady) onEngineReady,
  }) : _registrationLedger = registrationLedger,
       _callLedger = callLedger,
       _diagnosticsLedger = diagnosticsLedger,
       _logLedger = logLedger,
       _accountLabelForId = accountLabelForId,
       _onEngineReady = onEngineReady;

  final RegistrationLedger _registrationLedger;
  final CallLedger _callLedger;
  final DiagnosticsLedger _diagnosticsLedger;
  final LogLedger _logLedger;
  final String Function(String accountId) _accountLabelForId;
  final void Function(bool engineReady) _onEngineReady;
  final HistoryRepository _historyRepository = const HistoryRepository();

  void handle(VoipEvent event) {
    switch (event) {
      case EngineReady():
        _onEngineReady(true);
        _diagnosticsLedger.replace(
          DiagnosticsBundle(
            summary: 'PacketDial shell is attached to the bridge.',
            facts: <String, String>{
              ..._diagnosticsLedger.snapshot.facts,
              'Bridge ready': 'Yes',
            },
            logs: <String>['Engine ready', ..._diagnosticsLedger.snapshot.logs],
            lastExportPath: _diagnosticsLedger.snapshot.lastExportPath,
          ),
        );
      case AccountRegistrationChanged():
        _registrationLedger.upsert(
          event.accountId,
          state: _registrationStateFromBridge(event.state),
          reason: event.reason,
        );
        _logLedger.prepend('Account ${event.accountId} -> ${event.state.name}');
      case CallStateChanged():
        _reduceCallState(event);
      case CallMediaChanged():
        final call = _callLedger.snapshot.activeCall;
        if (call != null && call.id == event.callId) {
          _callLedger.setActiveCall(
            call.copyWith(
              state: event.audioActive ? CallState.active : call.state,
            ),
          );
        }
      case AudioRouteChanged():
        final call = _callLedger.snapshot.activeCall;
        if (call != null) {
          _callLedger.setActiveCall(
            call.copyWith(route: _audioRouteFromBridge(event.route)),
          );
        }
      case NativeLogEvent():
        final line = '[${event.level}] ${event.message}';
        _logLedger.prepend(line);
        _diagnosticsLedger.prependLog(line);
      case IncomingCallEvent():
        _callLedger.setActiveCall(
          ActiveCall(
            id: event.callId,
            accountId: event.accountId,
            remoteIdentity: event.remoteUri,
            displayName: event.displayName,
            direction: CallDirection.incoming,
            state: CallState.ringing,
            startedAt: DateTime.now(),
          ),
        );
      case DiagnosticsReportReady():
        _diagnosticsLedger.updateSummary(event.summary);
        _diagnosticsLedger.putFact(
          'Last export',
          event.path?.isNotEmpty == true ? event.path! : 'Requested only',
        );
        if (event.path?.isNotEmpty == true) {
          _diagnosticsLedger.markExportPath(event.path);
        }
        _diagnosticsLedger.prependSectionLine(
          'Diagnostics exports',
          event.path?.isNotEmpty == true
              ? 'Exported bundle: ${event.path}'
              : event.summary,
        );
      case AudioDevicesChanged():
        BridgeAudioDevice? selectedOutput;
        if (event.selectedOutputId != null) {
          for (final device in event.devices) {
            if (device.id == event.selectedOutputId) {
              selectedOutput = device;
              break;
            }
          }
        }
        _diagnosticsLedger.putFact(
          'Audio devices',
          '${event.devices.length} detected',
        );
        if (selectedOutput != null) {
          _diagnosticsLedger.putFact(
            'Selected audio output',
            selectedOutput.name,
          );
        }
        _diagnosticsLedger.putSection('Audio devices', <String>[
          if (event.selectedInputId != null)
            'Selected input id: ${event.selectedInputId}',
          if (event.selectedOutputId != null)
            'Selected output id: ${event.selectedOutputId}',
          ...event.devices.map(
            (device) => '${device.kind} #${device.id}: ${device.name}',
          ),
        ]);
      case TransferEvent():
        final line = switch (event.kind) {
          TransferEventKind.blindRequested =>
            'Blind transfer for ${event.callId} -> ${event.destination ?? 'unknown'}',
          TransferEventKind.attendedStarted =>
            'Attended transfer started for ${event.callId} using ${event.consultCallId ?? 'consult leg pending'}',
          TransferEventKind.attendedCompleted =>
            'Attended transfer completed for ${event.callId}',
          TransferEventKind.status =>
            event.message ?? 'Transfer status updated for ${event.callId}',
        };
        _diagnosticsLedger.prependSectionLine('Transfers', line);
        _logLedger.prepend(line);
      case LogBufferReceived():
        if (event.summary != null && event.summary!.isNotEmpty) {
          _diagnosticsLedger.updateSummary(event.summary!);
        }
        if (event.lines.isNotEmpty) {
          _diagnosticsLedger.putSection('Native log buffer', event.lines);
        }
      case RecordingEvent():
        final line = switch (event.kind) {
          RecordingEventKind.started =>
            'Recording started${event.callId == null ? '' : ' for call ${event.callId}'}',
          RecordingEventKind.stopped =>
            'Recording stopped${event.callId == null ? '' : ' for call ${event.callId}'}',
          RecordingEventKind.saved =>
            'Recording saved${event.filePath == null ? '' : ' at ${event.filePath}'}',
          RecordingEventKind.error =>
            event.message ?? 'Recording error reported by native engine',
        };
        _diagnosticsLedger.prependSectionLine('Recordings', line);
        _logLedger.prepend(line);
    }
  }

  void _reduceCallState(CallStateChanged event) {
    final current = _callLedger.snapshot.activeCall;
    final nextState = _callStateFromBridge(event.state);

    if (current == null || current.id != event.callId) {
      if (event.state == BridgeCallState.connecting ||
          event.state == BridgeCallState.ringing ||
          event.state == BridgeCallState.active) {
        _callLedger.setActiveCall(
          ActiveCall(
            id: event.callId,
            accountId: '',
            remoteIdentity: '',
            direction: CallDirection.outgoing,
            state: nextState,
            startedAt: DateTime.now(),
          ),
        );
      }
      return;
    }

    if (nextState == CallState.ended) {
      final endedAt = DateTime.now();
      _callLedger.prependHistory(
        _historyRepository.fromEndedCall(
          call: current,
          accountLabel: _accountLabelForId(current.accountId),
          endedAt: endedAt,
        ),
      );
      _callLedger.clearActiveCall();
      return;
    }

    _callLedger.setActiveCall(current.copyWith(state: nextState));
  }

  RegistrationState _registrationStateFromBridge(
    BridgeRegistrationState value,
  ) {
    switch (value) {
      case BridgeRegistrationState.registered:
        return RegistrationState.registered;
      case BridgeRegistrationState.registering:
        return RegistrationState.registering;
      case BridgeRegistrationState.failed:
        return RegistrationState.failed;
      case BridgeRegistrationState.unregistered:
        return RegistrationState.unregistered;
    }
  }

  CallState _callStateFromBridge(BridgeCallState value) {
    switch (value) {
      case BridgeCallState.ringing:
        return CallState.ringing;
      case BridgeCallState.connecting:
        return CallState.connecting;
      case BridgeCallState.active:
        return CallState.active;
      case BridgeCallState.held:
        return CallState.held;
      case BridgeCallState.ended:
        return CallState.ended;
      case BridgeCallState.idle:
        return CallState.idle;
    }
  }

  AudioRoute _audioRouteFromBridge(BridgeAudioRoute route) {
    switch (route) {
      case BridgeAudioRoute.speaker:
        return AudioRoute.speaker;
      case BridgeAudioRoute.bluetooth:
        return AudioRoute.bluetooth;
      case BridgeAudioRoute.headset:
        return AudioRoute.headset;
      case BridgeAudioRoute.earpiece:
        return AudioRoute.earpiece;
    }
  }
}

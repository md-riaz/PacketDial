sealed class VoipEvent {
  const VoipEvent();
}

class VoipInitConfig {
  const VoipInitConfig({required this.appName, required this.logLevel});

  final String appName;
  final String logLevel;
}

class VoipAccount {
  const VoipAccount({
    required this.id,
    required this.displayName,
    required this.username,
    required this.authUsername,
    required this.domain,
    required this.registrar,
    required this.transport,
    this.outboundProxy,
    this.tlsEnabled = false,
    this.iceEnabled = false,
    this.srtpEnabled = false,
    this.stunServer,
    this.turnServer,
    this.registerExpiresSeconds = 300,
    this.codecs = const <String>['opus', 'pcmu', 'pcma'],
    this.dtmfMode = 'rfc2833',
    this.voicemailNumber,
    this.password,
  });

  final String id;
  final String displayName;
  final String username;
  final String authUsername;
  final String domain;
  final String registrar;
  final String transport;
  final String? outboundProxy;
  final bool tlsEnabled;
  final bool iceEnabled;
  final bool srtpEnabled;
  final String? stunServer;
  final String? turnServer;
  final int registerExpiresSeconds;
  final List<String> codecs;
  final String dtmfMode;
  final String? voicemailNumber;
  final String? password;
}

enum BridgeRegistrationState { unregistered, registering, registered, failed }

enum BridgeCallState { idle, ringing, connecting, active, held, ended }

enum BridgeAudioRoute { earpiece, speaker, bluetooth, headset }

enum TransferEventKind {
  blindRequested,
  attendedStarted,
  attendedCompleted,
  status,
}

class CallStartResult {
  const CallStartResult({required this.callId, required this.accepted});

  final String callId;
  final bool accepted;
}

class AttendedTransferSession {
  const AttendedTransferSession({
    required this.originalCallId,
    required this.consultCallId,
  });

  final String originalCallId;
  final String consultCallId;
}

class EngineReady extends VoipEvent {
  const EngineReady();
}

class AccountRegistrationChanged extends VoipEvent {
  const AccountRegistrationChanged({
    required this.accountId,
    required this.state,
    this.reason,
  });

  final String accountId;
  final BridgeRegistrationState state;
  final String? reason;
}

class IncomingCallEvent extends VoipEvent {
  const IncomingCallEvent({
    required this.callId,
    required this.accountId,
    required this.remoteUri,
    this.displayName,
  });

  final String callId;
  final String accountId;
  final String remoteUri;
  final String? displayName;
}

class CallStateChanged extends VoipEvent {
  const CallStateChanged({required this.callId, required this.state});

  final String callId;
  final BridgeCallState state;
}

class CallMediaChanged extends VoipEvent {
  const CallMediaChanged({required this.callId, required this.audioActive});

  final String callId;
  final bool audioActive;
}

class AudioRouteChanged extends VoipEvent {
  const AudioRouteChanged({required this.route});

  final BridgeAudioRoute route;
}

class NativeLogEvent extends VoipEvent {
  const NativeLogEvent({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  final String level;
  final String message;
  final DateTime timestamp;
}

class BridgeAudioDevice {
  const BridgeAudioDevice({
    required this.id,
    required this.name,
    required this.kind,
  });

  final int id;
  final String name;
  final String kind;

  bool get isInput => kind.toLowerCase() == 'input';
  bool get isOutput => kind.toLowerCase() == 'output';
}

class AudioDevicesChanged extends VoipEvent {
  const AudioDevicesChanged({
    required this.devices,
    this.selectedInputId,
    this.selectedOutputId,
  });

  final List<BridgeAudioDevice> devices;
  final int? selectedInputId;
  final int? selectedOutputId;
}

class DiagnosticsReportReady extends VoipEvent {
  const DiagnosticsReportReady({
    required this.success,
    required this.summary,
    this.path,
  });

  final bool success;
  final String summary;
  final String? path;
}

enum RecordingEventKind { started, stopped, saved, error }

class LogBufferReceived extends VoipEvent {
  const LogBufferReceived({required this.lines, this.summary});

  final List<String> lines;
  final String? summary;
}

class RecordingEvent extends VoipEvent {
  const RecordingEvent({
    required this.kind,
    this.callId,
    this.filePath,
    this.message,
  });

  final RecordingEventKind kind;
  final String? callId;
  final String? filePath;
  final String? message;
}

class TransferEvent extends VoipEvent {
  const TransferEvent({
    required this.kind,
    required this.callId,
    this.consultCallId,
    this.destination,
    this.message,
  });

  final TransferEventKind kind;
  final String callId;
  final String? consultCallId;
  final String? destination;
  final String? message;
}

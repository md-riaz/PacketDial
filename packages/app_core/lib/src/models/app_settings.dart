import 'enums.dart';

class AppSettings {
  const AppSettings({
    this.startInTray = true,
    this.keepAwakeDuringCall = true,
    this.enableDiagnosticsOverlay = false,
    this.preferTcp = false,
    this.defaultTransport = SipTransport.tls,
    this.enableIceByDefault = true,
    this.enableSrtpByDefault = true,
    this.preferSystemNotifications = true,
  });

  final bool startInTray;
  final bool keepAwakeDuringCall;
  final bool enableDiagnosticsOverlay;
  final bool preferTcp;
  final SipTransport defaultTransport;
  final bool enableIceByDefault;
  final bool enableSrtpByDefault;
  final bool preferSystemNotifications;

  AppSettings copyWith({
    bool? startInTray,
    bool? keepAwakeDuringCall,
    bool? enableDiagnosticsOverlay,
    bool? preferTcp,
    SipTransport? defaultTransport,
    bool? enableIceByDefault,
    bool? enableSrtpByDefault,
    bool? preferSystemNotifications,
  }) {
    return AppSettings(
      startInTray: startInTray ?? this.startInTray,
      keepAwakeDuringCall: keepAwakeDuringCall ?? this.keepAwakeDuringCall,
      enableDiagnosticsOverlay:
          enableDiagnosticsOverlay ?? this.enableDiagnosticsOverlay,
      preferTcp: preferTcp ?? this.preferTcp,
      defaultTransport: defaultTransport ?? this.defaultTransport,
      enableIceByDefault: enableIceByDefault ?? this.enableIceByDefault,
      enableSrtpByDefault: enableSrtpByDefault ?? this.enableSrtpByDefault,
      preferSystemNotifications:
          preferSystemNotifications ?? this.preferSystemNotifications,
    );
  }
}

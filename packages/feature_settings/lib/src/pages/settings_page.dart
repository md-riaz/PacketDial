import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../widgets/settings_toggle_tile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        SettingsToggleTile(
          value: settings.startInTray,
          title: 'Start minimized to tray',
          onChanged: (value) =>
              onChanged(settings.copyWith(startInTray: value)),
        ),
        SettingsToggleTile(
          value: settings.keepAwakeDuringCall,
          title: 'Keep device awake during calls',
          onChanged: (value) =>
              onChanged(settings.copyWith(keepAwakeDuringCall: value)),
        ),
        SettingsToggleTile(
          value: settings.enableDiagnosticsOverlay,
          title: 'Enable diagnostics overlay',
          onChanged: (value) =>
              onChanged(settings.copyWith(enableDiagnosticsOverlay: value)),
        ),
        SettingsToggleTile(
          value: settings.preferTcp,
          title: 'Prefer TCP for new accounts',
          onChanged: (value) => onChanged(settings.copyWith(preferTcp: value)),
        ),
        ListTile(
          title: const Text('Default transport'),
          trailing: DropdownButton<SipTransport>(
            value: settings.defaultTransport,
            items: SipTransport.values
                .map(
                  (value) => DropdownMenuItem<SipTransport>(
                    value: value,
                    child: Text(value.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(settings.copyWith(defaultTransport: value));
              }
            },
          ),
        ),
        SettingsToggleTile(
          value: settings.enableIceByDefault,
          title: 'Enable ICE by default',
          onChanged: (value) =>
              onChanged(settings.copyWith(enableIceByDefault: value)),
        ),
        SettingsToggleTile(
          value: settings.enableSrtpByDefault,
          title: 'Enable SRTP by default',
          onChanged: (value) =>
              onChanged(settings.copyWith(enableSrtpByDefault: value)),
        ),
        SettingsToggleTile(
          value: settings.preferSystemNotifications,
          title: 'Prefer system notifications for incoming calls',
          onChanged: (value) =>
              onChanged(settings.copyWith(preferSystemNotifications: value)),
        ),
      ],
    );
  }
}

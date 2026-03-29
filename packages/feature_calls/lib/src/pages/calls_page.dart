import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../widgets/call_keypad.dart';
import '../widgets/call_transfer_panel.dart';

class CallsPage extends StatefulWidget {
  const CallsPage({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.dialPadText,
    required this.activeCall,
    required this.onAccountChanged,
    required this.onDialPadChanged,
    required this.onPlaceCall,
    required this.onSimulateIncoming,
    required this.onAnswer,
    required this.onReject,
    required this.onHangup,
    required this.onMuteChanged,
    required this.onHoldChanged,
    required this.onRouteChanged,
    required this.onSendDtmf,
    required this.onBlindTransfer,
    required this.onBeginAttendedTransfer,
    required this.supportsIncomingSimulation,
  });

  final List<SipAccount> accounts;
  final String? selectedAccountId;
  final String dialPadText;
  final ActiveCall? activeCall;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String> onDialPadChanged;
  final VoidCallback onPlaceCall;
  final VoidCallback onSimulateIncoming;
  final VoidCallback onAnswer;
  final VoidCallback onReject;
  final VoidCallback onHangup;
  final ValueChanged<bool> onMuteChanged;
  final ValueChanged<bool> onHoldChanged;
  final ValueChanged<AudioRoute> onRouteChanged;
  final ValueChanged<String> onSendDtmf;
  final ValueChanged<String> onBlindTransfer;
  final ValueChanged<String> onBeginAttendedTransfer;
  final bool supportsIncomingSimulation;

  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> {
  final TextEditingController _transferController = TextEditingController();

  @override
  void dispose() {
    _transferController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Dialer', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: widget.selectedAccountId,
                decoration: const InputDecoration(labelText: 'Source account'),
                items: widget.accounts
                    .map(
                      (account) => DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(account.label),
                      ),
                    )
                    .toList(),
                onChanged: widget.onAccountChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                key: ValueKey<String>(widget.dialPadText),
                initialValue: widget.dialPadText,
                onChanged: widget.onDialPadChanged,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  hintText: '2001 or sip:alice@example.com',
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: widget.onPlaceCall,
              icon: const Icon(Icons.call),
              label: const Text('Call'),
            ),
            const SizedBox(width: 12),
            if (widget.supportsIncomingSimulation)
              OutlinedButton.icon(
                onPressed: widget.onSimulateIncoming,
                icon: const Icon(Icons.phone_callback_outlined),
                label: const Text('Simulate incoming'),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: widget.activeCall == null
                ? const Text(
                    'No active call. Place a test call to exercise the bridge.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activeCall!.displayName ??
                            widget.activeCall!.remoteIdentity,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'State: ${widget.activeCall!.state.name} - ${widget.activeCall!.direction.name} - Route: ${widget.activeCall!.route.name}',
                      ),
                      const SizedBox(height: 16),
                      if (widget.activeCall!.direction ==
                              CallDirection.incoming &&
                          widget.activeCall!.state == CallState.ringing)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton(
                              onPressed: widget.onAnswer,
                              child: const Text('Answer'),
                            ),
                            FilledButton.tonal(
                              onPressed: widget.onReject,
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      if (widget.activeCall!.state != CallState.ringing) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.tonal(
                              onPressed: widget.onHangup,
                              child: const Text('Hang up'),
                            ),
                            FilterChip(
                              selected: widget.activeCall!.muted,
                              label: const Text('Mute'),
                              onSelected: widget.onMuteChanged,
                            ),
                            FilterChip(
                              selected: widget.activeCall!.onHold,
                              label: const Text('Hold'),
                              onSelected: widget.onHoldChanged,
                            ),
                            DropdownButton<AudioRoute>(
                              value: widget.activeCall!.route,
                              items: AudioRoute.values
                                  .map(
                                    (route) => DropdownMenuItem<AudioRoute>(
                                      value: route,
                                      child: Text(route.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  widget.onRouteChanged(value);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CallTransferPanel(
                          controller: _transferController,
                          onBlindTransfer: widget.onBlindTransfer,
                          onBeginAttendedTransfer:
                              widget.onBeginAttendedTransfer,
                        ),
                        const SizedBox(height: 16),
                        CallKeypad(onSendDtmf: widget.onSendDtmf),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

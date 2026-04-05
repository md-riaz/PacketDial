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
    final hasActiveCall = widget.activeCall != null;
    final isNarrow = MediaQuery.sizeOf(context).width < 700;

    return ListView(
      padding: EdgeInsets.fromLTRB(isNarrow ? 12 : 16, 0, isNarrow ? 12 : 16, 16),
      children: [
        if (isNarrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.call_outlined, color: Color(0xFF1DA8D6), size: 20),
                  const SizedBox(width: 6),
                  Text('Dial Pad', style: theme.textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FB),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD2E4F2)),
                ),
                child: Text(
                  hasActiveCall ? 'In Call' : 'Idle',
                  style: const TextStyle(
                    color: Color(0xFF4F738A),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              const Icon(Icons.call_outlined, color: Color(0xFF1DA8D6), size: 20),
              const SizedBox(width: 6),
              Text('Dial Pad', style: theme.textTheme.headlineSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FB),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD2E4F2)),
                ),
                child: Text(
                  hasActiveCall ? 'In Call' : 'Idle',
                  style: const TextStyle(
                    color: Color(0xFF4F738A),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (isNarrow)
                  Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: widget.selectedAccountId,
                        decoration: const InputDecoration(
                          labelText: 'Account',
                          prefixIcon: Icon(Icons.account_circle_outlined),
                        ),
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
                      const SizedBox(height: 10),
                      TextFormField(
                        key: ValueKey<String>(widget.dialPadText),
                        initialValue: widget.dialPadText,
                        onChanged: widget.onDialPadChanged,
                        decoration: const InputDecoration(
                          labelText: 'Number / SIP URI',
                          hintText: '2001 or sip:alice@example.com',
                          prefixIcon: Icon(Icons.dialpad_outlined),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: widget.selectedAccountId,
                          decoration: const InputDecoration(
                            labelText: 'Account',
                            prefixIcon: Icon(Icons.account_circle_outlined),
                          ),
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
                            labelText: 'Number / SIP URI',
                            hintText: '2001 or sip:alice@example.com',
                            prefixIcon: Icon(Icons.dialpad_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: widget.onPlaceCall,
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call'),
                    ),
                    if (widget.supportsIncomingSimulation)
                      OutlinedButton.icon(
                        onPressed: widget.onSimulateIncoming,
                        icon: const Icon(Icons.phone_callback_outlined, size: 18),
                        label: const Text('Simulate incoming'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: widget.activeCall == null
                ? const Row(
                    children: [
                      Icon(Icons.phone_disabled_outlined, color: Color(0xFF8AA2B2)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No active call. Place a call to start media/session controls.',
                          style: TextStyle(color: Color(0xFF6B7F8E)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activeCall!.displayName ?? widget.activeCall!.remoteIdentity,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'State: ${widget.activeCall!.state.name} • ${widget.activeCall!.direction.name} • Route: ${widget.activeCall!.route.name}',
                        style: const TextStyle(color: Color(0xFF6B7F8E), fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      if (widget.activeCall!.direction == CallDirection.incoming &&
                          widget.activeCall!.state == CallState.ringing)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton(
                              onPressed: widget.onAnswer,
                              child: const Text('Answer'),
                            ),
                            OutlinedButton(
                              onPressed: widget.onReject,
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      if (widget.activeCall!.state != CallState.ringing) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: widget.onHangup,
                              icon: const Icon(Icons.call_end_outlined),
                              label: const Text('Hang up'),
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
                          onBeginAttendedTransfer: widget.onBeginAttendedTransfer,
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

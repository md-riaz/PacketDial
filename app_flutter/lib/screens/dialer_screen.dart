import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/engine_channel.dart';
import '../core/account_service.dart';
import '../models/account_schema.dart';
import '../models/call.dart';
import '../models/media_stats.dart';
import '../providers/engine_provider.dart';

final selectedAccountProvider = FutureProvider<AccountSchema?>((ref) {
  return ref.read(accountServiceProvider).getSelectedAccount();
});

class DialerScreen extends ConsumerStatefulWidget {
  const DialerScreen({super.key});

  @override
  ConsumerState<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends ConsumerState<DialerScreen> {
  final _uriCtrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus dialer on load (Spec 6.1)
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _uriCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _dialKey(String digit, bool isCallActive) {
    if (isCallActive) {
      EngineChannel.instance.sendDtmf(digit);
    } else {
      setState(() => _uriCtrl.text += digit);
    }
    _focusNode.requestFocus();
  }

  void _backspace() {
    if (_uriCtrl.text.isNotEmpty) {
      setState(() =>
          _uriCtrl.text = _uriCtrl.text.substring(0, _uriCtrl.text.length - 1));
    }
    _focusNode.requestFocus();
  }

  void _call(AccountSchema? activeAccount) {
    if (activeAccount == null) return;
    final raw = _uriCtrl.text.trim();
    if (raw.isEmpty) return;

    final accountName = activeAccount.accountName;
    final server = activeAccount.server;

    String uri = raw;
    if (!uri.contains(':')) {
      uri = server.isNotEmpty ? 'sip:$raw@$server' : 'sip:$raw';
    } else if (!uri.startsWith('sip:') && !uri.startsWith('sips:')) {
      uri = 'sip:$raw';
    }

    EngineChannel.instance.engine.makeCall(accountName, uri);
  }

  void _hangup() => EngineChannel.instance.engine.hangup();

  @override
  Widget build(BuildContext context) {
    final activeAccountAsync = ref.watch(selectedAccountProvider);
    final activeCall = ref.watch(activeCallProvider);
    final stats = ref.watch(activeCallMediaStatsProvider);

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const _CallActionIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const _HangupActionIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD):
            const _FocusActionIntent(),
      },
      child: Actions(
        actions: {
          _CallActionIntent: CallbackAction<_CallActionIntent>(
            onInvoke: (_) => _call(activeAccountAsync.value),
          ),
          _HangupActionIntent: CallbackAction<_HangupActionIntent>(
            onInvoke: (_) => _hangup(),
          ),
          _FocusActionIntent: CallbackAction<_FocusActionIntent>(
            onInvoke: (_) => _focusNode.requestFocus(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: activeAccountAsync.when(
              data: (activeAccount) => Padding(
                padding: const EdgeInsets.all(8.0), // Spec 5.1 Density
                child: Column(
                  children: [
                    // 1. High-Density Status Header
                    _buildCompactHeader(activeAccount),
                    const SizedBox(height: 8),

                    // 2. Active Call Panel (Stack-ready)
                    if (activeCall != null)
                      _ActiveCallCard(
                          call: activeCall, stats: stats, onHangup: _hangup)
                    else
                      const SizedBox(
                          height: 100,
                          child: Center(
                              child: Text('READY',
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      letterSpacing: 2)))),

                    const Divider(height: 16),

                    // 3. Dialing Input
                    _buildDialInput(),

                    const SizedBox(height: 8),

                    // 4. Integrated Numpad & Controls
                    Expanded(child: _buildNumpadGrid(activeCall)),

                    const SizedBox(height: 8),

                    // 5. Action Bar
                    _buildMainActionBar(activeAccount, activeCall),
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(AccountSchema? account) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_box, size: 14, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              account?.displayName ?? 'No Active Account',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          const Text('KBD ON',
              style: TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDialInput() {
    return TextField(
      controller: _uriCtrl,
      focusNode: _focusNode,
      style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.normal, letterSpacing: 1),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: 'Enter number or URI',
        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.backspace_outlined, size: 18),
          onPressed: _backspace,
        ),
      ),
      onSubmitted: (_) => _call(null), // Handled by Actions
    );
  }

  Widget _buildNumpadGrid(ActiveCall? activeCall) {
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 1.8,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (final label in [
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '*',
          '0',
          '#'
        ])
          _NumpadButton(
              label: label, onTap: () => _dialKey(label, activeCall != null)),
      ],
    );
  }

  Widget _buildMainActionBar(AccountSchema? account, ActiveCall? call) {
    bool isCall = call != null;
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: isCall ? _hangup : () => _call(account),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isCall ? Colors.red.shade600 : Colors.green.shade600,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isCall ? Icons.call_end : Icons.call, size: 18),
                const SizedBox(width: 8),
                Text(isCall ? 'HANG UP (Esc)' : 'DIAL (Enter)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NumpadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NumpadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
    );
  }
}

class _ActiveCallCard extends StatelessWidget {
  final ActiveCall call;
  final MediaStats? stats;
  final VoidCallback onHangup;
  const _ActiveCallCard(
      {required this.call, this.stats, required this.onHangup});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                  radius: 16, child: Icon(Icons.person, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(call.uri,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(call.state.label,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.blueGrey)),
                  ],
                ),
              ),
              _TimerWidget(startTime: call.startedAt),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _IconButton(
                  icon: call.muted ? Icons.mic_off : Icons.mic,
                  label: 'MUTE',
                  active: call.muted,
                  onTap: () => EngineChannel.instance.setMute(!call.muted)),
              _IconButton(
                  icon: Icons.pause,
                  label: 'HOLD',
                  active: call.onHold,
                  onTap: () => EngineChannel.instance.setHold(!call.onHold)),
              _IconButton(
                  icon: Icons.grid_on,
                  label: 'KEYPAD',
                  active: false,
                  onTap: () {}),
              _IconButton(
                  icon: Icons.swap_horiz,
                  label: 'XFER',
                  active: false,
                  onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _IconButton(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 18, color: active ? Colors.orange : Colors.indigo),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.orange : Colors.indigo)),
        ],
      ),
    );
  }
}

class _TimerWidget extends StatefulWidget {
  final DateTime? startTime;
  const _TimerWidget({this.startTime});

  @override
  State<_TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<_TimerWidget> {
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_TimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.startTime == null) {
      setState(() => _duration = Duration.zero);
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = DateTime.now().difference(widget.startTime!);
      });
    });
    // Initial sync
    setState(() {
      _duration = DateTime.now().difference(widget.startTime!);
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(_duration),
      style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.blue),
    );
  }
}

// Keyboard Action Intents
class _CallActionIntent extends Intent {
  const _CallActionIntent();
}

class _HangupActionIntent extends Intent {
  const _HangupActionIntent();
}

class _FocusActionIntent extends Intent {
  const _FocusActionIntent();
}

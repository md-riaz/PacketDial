import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../core/sip_uri_utils.dart';
import '../core/engine_channel.dart';
import '../core/account_service.dart';
import '../models/account_schema.dart';
import '../models/account.dart';
import '../models/audio_device.dart';
import '../models/call.dart';
import '../models/media_stats.dart';
import '../providers/engine_provider.dart';

final selectedAccountProvider = FutureProvider<AccountSchema?>((ref) {
  return ref.watch(accountServiceProvider).getSelectedAccount();
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
    // Local feedback (Spec 6.2)
    HapticFeedback.lightImpact();
    EngineChannel.instance.playDtmf(digit);

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

  void _call(AccountSchema? activeAccount, Account? activeAccountState,
      List<AudioDevice> audioDevices) {
    if (activeAccount == null) return;
    final raw = _uriCtrl.text.trim();
    if (raw.isEmpty) return;

    final isRegistered =
        activeAccountState?.registrationState == RegistrationState.registered;
    final hasInput = audioDevices.any((d) => d.isInput);
    final hasOutput = audioDevices.any((d) => d.isOutput);

    if (!isRegistered || !hasInput || !hasOutput) {
      _showPreFlightChecklist(
        context,
        activeAccount: activeAccount,
        isRegistered: isRegistered,
        hasInput: hasInput,
        hasOutput: hasOutput,
        onCallAnyway: () => _executeCall(activeAccount, raw),
      );
      return;
    }

    _executeCall(activeAccount, raw);
  }

  void _executeCall(AccountSchema activeAccount, String raw) {
    final accountId = activeAccount.uuid;
    final server = activeAccount.server;

    String uri = raw;
    if (!uri.contains(':')) {
      uri = server.isNotEmpty ? 'sip:$raw@$server' : 'sip:$raw';
    } else if (!uri.startsWith('sip:') && !uri.startsWith('sips:')) {
      uri = 'sip:$raw';
    }

    EngineChannel.instance.engine.makeCall(accountId, uri);
  }

  void _showPreFlightChecklist(
    BuildContext context, {
    required AccountSchema activeAccount,
    required bool isRegistered,
    required bool hasInput,
    required bool hasOutput,
    required VoidCallback onCallAnyway,
  }) {
    final hasError = !isRegistered;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          title: const Text('Pre-flight Checklist',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChecklistItem(
                label: 'Account Registered',
                isOk: isRegistered,
                isWarning: false,
              ),
              const SizedBox(height: 8),
              _buildChecklistItem(
                label: 'Microphone Detected',
                isOk: hasInput,
                isWarning: true,
              ),
              const SizedBox(height: 8),
              _buildChecklistItem(
                label: 'Speaker Detected',
                isOk: hasOutput,
                isWarning: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: hasError
                  ? null
                  : () {
                      Navigator.pop(context);
                      onCallAnyway();
                    },
              child: Text(
                'Call Anyway',
                style: TextStyle(
                  color: hasError
                      ? AppTheme.textTertiary.withValues(alpha: 0.5)
                      : AppTheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChecklistItem({
    required String label,
    required bool isOk,
    required bool isWarning,
  }) {
    IconData icon;
    Color color;

    if (isOk) {
      icon = Icons.check_circle;
      color = AppTheme.callGreen;
    } else if (isWarning) {
      icon = Icons.warning;
      color = AppTheme.warningAmber;
    } else {
      icon = Icons.cancel;
      color = AppTheme.errorRed;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
      ],
    );
  }

  void _hangup() => EngineChannel.instance.engine.hangup();

  // Sub-labels for numpad keys
  static const _subLabels = {
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+',
  };

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
            onInvoke: (_) {
              final audioDevices = ref.read(audioDevicesProvider);
              final activeAccountState = ref.read(activeAccountProvider);
              _call(activeAccountAsync.value, activeAccountState, audioDevices);
              return null;
            },
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
          child: activeAccountAsync.when(
            data: (activeAccount) {
              final audioDevices = ref.watch(audioDevicesProvider);
              final activeAccountState = ref.watch(activeAccountProvider);
              return Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // 1. Compact Header
                    _buildCompactHeader(activeAccount),
                    const SizedBox(height: 10),

                    // 2. Active Call Panel
                    if (activeCall != null)
                      _ActiveCallCard(
                          call: activeCall, stats: stats, onHangup: _hangup)
                    else
                      _buildReadyIndicator(),

                    const SizedBox(height: 10),

                    // 3. Dialing Input
                    _buildDialInput(),

                    const SizedBox(height: 10),

                    // 4. Integrated Numpad
                    Expanded(child: _buildNumpadGrid(activeCall)),

                    const SizedBox(height: 10),

                    // 5. Action Bar
                    _buildMainActionBar(activeAccount, activeAccountState,
                        activeCall, audioDevices),
                  ],
                ),
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  AppTheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppTheme.errorRed)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(AccountSchema? account) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppTheme.glassCard(borderRadius: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.account_circle,
                size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              account?.displayName ?? 'No Active Account',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard, size: 10, color: AppTheme.accent),
                SizedBox(width: 3),
                Text('KBD',
                    style: TextStyle(
                        fontSize: 8,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyIndicator() {
    return Container(
      height: 80,
      decoration: AppTheme.glassCard(
        borderRadius: 10,
        color: AppTheme.surfaceCard.withValues(alpha: 0.4),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_enabled,
                size: 24, color: AppTheme.callGreen.withValues(alpha: 0.5)),
            const SizedBox(height: 4),
            Text('READY',
                style: TextStyle(
                  color: AppTheme.textTertiary.withValues(alpha: 0.7),
                  fontSize: 10,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDialInput() {
    return TextField(
      controller: _uriCtrl,
      focusNode: _focusNode,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w300,
        letterSpacing: 2,
        color: AppTheme.textPrimary,
        fontFamily: 'monospace',
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: 'Enter number or URI',
        hintStyle: TextStyle(
          fontSize: 14,
          color: AppTheme.textTertiary.withValues(alpha: 0.5),
          letterSpacing: 0,
        ),
        filled: true,
        fillColor: AppTheme.surfaceCard.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        suffixIcon: _uriCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.backspace_outlined,
                    size: 18, color: AppTheme.textTertiary),
                onPressed: _backspace,
              )
            : null,
      ),
      onSubmitted: (_) => _call(null, null, []),
    );
  }

  Widget _buildNumpadGrid(ActiveCall? activeCall) {
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 1.6,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
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
            label: label,
            subLabel: _subLabels[label],
            onTap: () => _dialKey(label, activeCall != null),
          ),
      ],
    );
  }

  Widget _buildMainActionBar(
      AccountSchema? account,
      Account? activeAccountState,
      ActiveCall? call,
      List<AudioDevice> audioDevices) {
    bool isCall = call != null;
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: isCall
            ? AppTheme.hangupButtonGradient
            : AppTheme.callButtonGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isCall ? AppTheme.hangupRed : AppTheme.callGreen)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCall
              ? _hangup
              : () => _call(account, activeAccountState, audioDevices),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isCall ? Icons.call_end : Icons.call,
                  size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                isCall ? 'HANG UP (Esc)' : 'DIAL (Enter)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Numpad Button ─────────────────────────────────────────────────────────
class _NumpadButton extends StatefulWidget {
  final String label;
  final String? subLabel;
  final VoidCallback onTap;
  const _NumpadButton(
      {required this.label, this.subLabel, required this.onTap});

  @override
  State<_NumpadButton> createState() => _NumpadButtonState();
}

class _NumpadButtonState extends State<_NumpadButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.numpadGradient,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _pressed
                  ? AppTheme.primary.withValues(alpha: 0.5)
                  : AppTheme.border.withValues(alpha: 0.4),
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: _pressed
                ? AppTheme.glowShadow(AppTheme.primary, blur: 8)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: _pressed ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
              if (widget.subLabel != null) ...[
                const SizedBox(height: 1),
                Text(
                  widget.subLabel!,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary.withValues(alpha: 0.6),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Active Call Card ──────────────────────────────────────────────────────
class _ActiveCallCard extends StatelessWidget {
  final ActiveCall call;
  final MediaStats? stats;
  final VoidCallback onHangup;
  const _ActiveCallCard(
      {required this.call, this.stats, required this.onHangup});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCard(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderColor: AppTheme.accent.withValues(alpha: 0.25),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Pulsing avatar
              const _PulsingAvatar(color: AppTheme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(SipUriUtils.friendlyName(call.uri),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(call.state.label,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.accent.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              _TimerWidget(
                startTime: call.startedAt,
                accumulatedSeconds: call.accumulatedSeconds,
                lastResumedAt: call.lastResumedAt,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallControlButton(
                icon: call.muted ? Icons.mic_off : Icons.mic,
                label: 'MUTE',
                active: call.muted,
                enabled: call.state != CallState.ringing,
                onTap: () => EngineChannel.instance.setMute(!call.muted),
              ),
              _CallControlButton(
                icon: Icons.pause_circle_outline,
                label: 'HOLD',
                active: call.onHold,
                enabled: call.state != CallState.ringing,
                onTap: () => EngineChannel.instance.setHold(!call.onHold),
              ),
              _CallControlButton(
                icon: Icons.grid_on,
                label: 'KEYPAD',
                active: false,
                enabled: call.state != CallState.ringing,
                onTap: () {},
              ),
              _CallControlButton(
                icon: Icons.swap_horiz,
                label: 'XFER',
                active: false,
                enabled: call.state != CallState.ringing,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pulsing Avatar ───────────────────────────────────────────────────────
class _PulsingAvatar extends StatefulWidget {
  final Color color;
  const _PulsingAvatar({required this.color});

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.2 + _ctrl.value * 0.3),
              blurRadius: 8 + _ctrl.value * 8,
              spreadRadius: _ctrl.value * 2,
            ),
          ],
        ),
        child: child,
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: widget.color.withValues(alpha: 0.2),
        child: Icon(Icons.person, size: 20, color: widget.color),
      ),
    );
  }
}

// ── Call Control Button ──────────────────────────────────────────────────
class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.active,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Opacity(
        opacity: 0.4,
        child: _buildBody(),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final color = active ? AppTheme.warningAmber : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.warningAmber.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? AppTheme.warningAmber.withValues(alpha: 0.3)
              : AppTheme.border.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ── Call Timer Widget ────────────────────────────────────────────────────
class _TimerWidget extends StatefulWidget {
  final DateTime? startTime;
  final int accumulatedSeconds;
  final DateTime? lastResumedAt;

  const _TimerWidget({
    this.startTime,
    this.accumulatedSeconds = 0,
    this.lastResumedAt,
  });

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
    if (oldWidget.startTime != widget.startTime ||
        oldWidget.lastResumedAt != widget.lastResumedAt ||
        oldWidget.accumulatedSeconds != widget.accumulatedSeconds) {
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
      _updateDuration();
    });
    // Initial sync
    _updateDuration();
  }

  void _updateDuration() {
    setState(() {
      if (widget.lastResumedAt != null) {
        _duration = Duration(seconds: widget.accumulatedSeconds) +
            DateTime.now().difference(widget.lastResumedAt!);
      } else {
        _duration = Duration(seconds: widget.accumulatedSeconds);
      }
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _formatDuration(_duration),
        style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppTheme.accentBright),
      ),
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

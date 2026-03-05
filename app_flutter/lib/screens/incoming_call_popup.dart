import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_theme.dart';
import '../core/sip_uri_utils.dart';

/// Incoming call popup window — launched as a sub-window by the main app.
///
/// Arguments JSON: { "uri": "sip:...", "direction": "Incoming", "account": "..." }
class IncomingCallPopup extends StatefulWidget {
  final WindowController windowController;
  final Map<String, dynamic> callInfo;
  final Map<String, dynamic>? parentBounds;

  const IncomingCallPopup({
    super.key,
    required this.windowController,
    required this.callInfo,
    this.parentBounds,
  });

  @override
  State<IncomingCallPopup> createState() => _IncomingCallPopupState();
}

class _IncomingCallPopupState extends State<IncomingCallPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _answered = false;

  String get callerName =>
      SipUriUtils.friendlyName(widget.callInfo['uri'] as String?);
  String? get callerDomain =>
      SipUriUtils.extractDomain(widget.callInfo['uri'] as String?);
  String get accountName =>
      widget.callInfo['account'] as String? ?? 'SIP Account';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _configureWindow();
  }

  Future<void> _configureWindow() async {
    // Configure the sub-window via windowManager
    await windowManager.ensureInitialized();
    const size = Size(320, 240);
    await windowManager.setSize(size);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setTitle('Incoming Call');
    await windowManager.setSkipTaskbar(true);

    // Position relative to parent
    if (widget.parentBounds != null) {
      final pb = widget.parentBounds!;
      final double px = (pb['x'] as num).toDouble();
      final double py = (pb['y'] as num).toDouble();
      final double pw = (pb['w'] as num).toDouble();
      final double ph = (pb['h'] as num).toDouble();

      final double x = px + (pw / 2) - (size.width / 2);
      final double y = py + (ph / 2) - (size.height / 2);
      await windowManager.setPosition(Offset(x, y));
    } else {
      await windowManager.center();
    }

    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _answer() {
    setState(() => _answered = true);
    widget.windowController.invokeMethod('answer');
    // Close after a brief delay to show the "Connecting..." state
    Future.delayed(const Duration(milliseconds: 500), _closeWindow);
  }

  void _reject() {
    widget.windowController.invokeMethod('reject');
    _closeWindow();
  }

  void _closeWindow() {
    windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: AppTheme.surface,
        body: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D0D1A), Color(0xFF1A1040)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Native title bar used, no internal bar needed
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pulsing call indicator
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, child) => Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.callGreen.withValues(
                                    alpha: 0.15 + _pulseCtrl.value * 0.25),
                                blurRadius: 16 + _pulseCtrl.value * 16,
                                spreadRadius: _pulseCtrl.value * 4,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              AppTheme.callGreen.withValues(alpha: 0.15),
                          child: Text(
                            callerName.isNotEmpty
                                ? callerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.callGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Caller name
                      Text(
                        callerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),

                      // Domain / account info
                      if (callerDomain != null)
                        Text(
                          callerDomain!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      Text(
                        _answered ? 'Connecting…' : 'via $accountName',
                        style: TextStyle(
                          fontSize: 11,
                          color: _answered
                              ? AppTheme.accentBright
                              : AppTheme.textTertiary.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action buttons
                      if (!_answered)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Reject
                            _ActionButton(
                              icon: Icons.call_end,
                              label: 'Reject',
                              gradient: AppTheme.hangupButtonGradient,
                              glowColor: AppTheme.hangupRed,
                              onTap: _reject,
                            ),
                            const SizedBox(width: 24),
                            // Answer
                            _ActionButton(
                              icon: Icons.call,
                              label: 'Answer',
                              gradient: AppTheme.callButtonGradient,
                              glowColor: AppTheme.callGreen,
                              onTap: _answer,
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              AppTheme.accentBright.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final Color glowColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: widget.gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

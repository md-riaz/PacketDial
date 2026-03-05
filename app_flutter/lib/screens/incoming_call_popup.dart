import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_theme.dart';
import '../core/sip_uri_utils.dart';
import '../core/multi_window/window_controller_extension.dart';

/// Incoming call popup window — launched as a sub-window by the main app.
///
/// Arguments JSON: { "uri": "sip:...", "direction": "Incoming", "account": "..." }
class IncomingCallPopup extends StatefulWidget {
  final WindowController windowController;
  final Map<String, dynamic> callInfo;

  const IncomingCallPopup({
    super.key,
    required this.windowController,
    required this.callInfo,
  });

  @override
  State<IncomingCallPopup> createState() => _IncomingCallPopupState();
}

class _IncomingCallPopupState extends State<IncomingCallPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _answered = false;
  bool _isClosing = false;

  String get callerName =>
      SipUriUtils.friendlyName(widget.callInfo['uri'] as String?);
  String? get callerDomain =>
      SipUriUtils.extractDomain(widget.callInfo['uri'] as String?);
  String get accountName =>
      widget.callInfo['account_name'] as String? ?? 'SIP Account';
  String get accountUser =>
      widget.callInfo['account_user'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _configureWindow();
    
    // Set up window method handler for close requests (non-blocking)
    _setupWindowHandler();
  }

  void _configureWindow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appWindow.minSize = const Size(320, 240);
      appWindow.size = const Size(320, 240);
      appWindow.alignment = Alignment.center;
      appWindow.title = 'Incoming Call';
      appWindow.show();
    });
  }
  
  void _setupWindowHandler() {
    // Fire and forget - handler will be ready before any close request
    widget.windowController.initWindowMethodHandler().catchError((e) {
      debugPrint('[IncomingCallPopup] Handler setup error: $e');
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _answer() async {
    if (_isClosing) return;
    setState(() => _answered = true);
    try {
      await widget.windowController.invokeMethod('answer');
    } catch (e) {
      debugPrint('[IncomingCallPopup] Error sending answer: $e');
    }
    // Close after a brief delay to show the "Connecting..." state
    await Future.delayed(const Duration(milliseconds: 500));
    _closeWindow();
  }

  void _reject() async {
    if (_isClosing) return;
    try {
      await widget.windowController.invokeMethod('reject');
    } catch (e) {
      debugPrint('[IncomingCallPopup] Error sending reject: $e');
    }
    _closeWindow();
  }

  void _closeWindow() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      debugPrint('[IncomingCallPopup] Closing window');
      // Give the main window time to process the answer/reject
      await Future.delayed(const Duration(milliseconds: 200));
      // Use the extension method to close (desktop_multi_window pattern)
      await widget.windowController.closeWindow();
    } catch (e) {
      debugPrint('[IncomingCallPopup] Error closing window: $e');
    }
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
              // Use bitsdojo_window for title bar interaction if needed,
              // but here we just rely on native decorations.
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
                        callerName.isNotEmpty ? callerName : 'Unknown Caller',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (callerDomain != null && callerDomain!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          callerDomain!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Account info badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sim_card,
                              color: AppTheme.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  accountName,
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (accountUser.isNotEmpty)
                                  Text(
                                    accountUser,
                                    style: TextStyle(
                                      color: AppTheme.primary.withValues(alpha: 0.7),
                                      fontSize: 9,
                                    ),
                                  ),
                              ],
                            ),
                          ],
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

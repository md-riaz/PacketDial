import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/sip_uri_utils.dart';
import '../models/customer_data.dart';

/// Full-screen incoming call overlay.
class IncomingCallBanner extends StatefulWidget {
  final Map<String, dynamic> callInfo;
  final VoidCallback onAnswer;
  final VoidCallback onReject;

  const IncomingCallBanner({
    super.key,
    required this.callInfo,
    required this.onAnswer,
    required this.onReject,
  });

  @override
  State<IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends State<IncomingCallBanner>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  bool _answered = false;
  CustomerData? _customerData;

  String get callerName =>
      SipUriUtils.friendlyName(widget.callInfo['uri'] as String?);
  String? get callerDomain =>
      SipUriUtils.extractDomain(widget.callInfo['uri'] as String?);
  String get accountName =>
      widget.callInfo['account_name'] as String? ?? 'SIP Account';
  String get accountUser => widget.callInfo['account_user'] as String? ?? '';
  String? get callerNumber =>
      SipUriUtils.extractNumber(widget.callInfo['uri'] as String?);
  String? get extId => widget.callInfo['extid'] as String?;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _loadCustomerData();

    // Start slide-in animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideCtrl.forward();
    });
  }

  Future<void> _loadCustomerData() async {
    final customerJson =
        widget.callInfo['customer_data'] as Map<String, dynamic>?;
    if (customerJson != null) {
      if (!mounted) return;
      setState(() {
        _customerData = CustomerData.fromJson(customerJson);
      });
      return;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _answer() {
    if (_answered) return;
    setState(() => _answered = true);
    widget.onAnswer();

    // Start slide-out animation after brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _slideCtrl.reverse().then((_) {
          // Banner will be removed by parent when animation completes
        });
      }
    });
  }

  void _reject() {
    widget.onReject();

    // Start slide-out animation
    _slideCtrl.reverse().then((_) {
      // Banner will be removed by parent when animation completes
    });
  }

  void _openCallerLink() {
    if (_customerData == null || !_customerData!.hasContactLink) return;

    final url = _customerData!.contactLink;
    debugPrint('[IncomingCallBanner] Opening CRM link: $url');

    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomerData = _customerData != null && _customerData!.hasData;
    final displayName = hasCustomerData
        ? _customerData!.contactName
        : (callerName.isNotEmpty ? callerName : 'Unknown Caller');
    final displayCompany = hasCustomerData ? _customerData!.company : null;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideCtrl,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(
          opacity: _slideCtrl,
          child: Container(
            color: const Color(0xFF070A16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D0D1A), Color(0xFF161035)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.callGreen.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, child) => Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.callGreen.withValues(
                                        alpha: 0.25 + _pulseCtrl.value * 0.35),
                                    blurRadius: 16 + _pulseCtrl.value * 10,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  AppTheme.callGreen.withValues(alpha: 0.16),
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.callGreenBright,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Incoming Call',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.callGreenBright,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (callerNumber != null && callerNumber != displayName)
                        Text(
                          callerNumber!,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      if (callerDomain != null && callerDomain!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          callerDomain!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF202050),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sim_card,
                                size: 16, color: AppTheme.textPrimary),
                            const SizedBox(width: 8),
                            Text(
                              accountName,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (accountUser.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '($accountUser)',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (displayCompany != null &&
                          displayCompany.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          displayCompany,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.accentBright,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_customerData?.hasContactLink == true) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openCallerLink,
                            icon: const Icon(Icons.open_in_browser, size: 18),
                            label: const Text('Open CRM Record'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: BorderSide(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!_answered)
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.call_end,
                                label: 'Reject (Esc)',
                                gradient: AppTheme.hangupButtonGradient,
                                glowColor: AppTheme.hangupRed,
                                onTap: _reject,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.call,
                                label: 'Answer',
                                gradient: AppTheme.callButtonGradient,
                                glowColor: AppTheme.callGreen,
                                onTap: _answer,
                              ),
                            ),
                          ],
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2.6),
                        ),
                    ],
                  ),
                ),
              ),
            ),
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
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

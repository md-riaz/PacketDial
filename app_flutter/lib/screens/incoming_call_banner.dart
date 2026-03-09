import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/sip_uri_utils.dart';
import '../models/customer_data.dart';

/// Incoming call banner - overlay shown at top of main window
/// Replaces the separate multi-window popup
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

    return SlideTransition(
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
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0D0D1A),
                Color(0xFF1A1040),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.callGreen.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.callGreen.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with pulse indicator
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, child) => Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.callGreen.withValues(
                                  alpha: 0.3 + _pulseCtrl.value * 0.4),
                              blurRadius: 12 + _pulseCtrl.value * 12,
                              spreadRadius: _pulseCtrl.value * 3,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppTheme.callGreen.withValues(alpha: 0.2),
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.callGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.call,
                                color: AppTheme.callGreen,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'INCOMING CALL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      AppTheme.callGreen.withValues(alpha: 0.9),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Caller details
                if (callerNumber != null && callerNumber != displayName) ...[
                  Text(
                    callerNumber!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                if (callerDomain != null && callerDomain!.isNotEmpty) ...[
                  Text(
                    callerDomain!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Company badge
                if (displayCompany != null && displayCompany.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displayCompany,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Account info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3),
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
                      Text(
                        accountName,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // CRM link button
                if (_customerData?.hasContactLink == true) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openCallerLink,
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('Open CRM Record'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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
                      const SizedBox(width: 32),
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
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(
                        AppTheme.accentBright.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
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
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: widget.gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 11,
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

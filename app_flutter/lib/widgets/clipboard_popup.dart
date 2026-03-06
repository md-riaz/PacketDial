import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_theme.dart';
import '../core/dialing_rules_service.dart';
import '../core/engine_channel.dart';

/// Clipboard popup widget - shows when a phone number is detected in clipboard
/// This is designed to be shown as an overlay on the main window
class ClipboardPopup extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback? onDismiss;

  const ClipboardPopup({
    super.key,
    required this.phoneNumber,
    this.onDismiss,
  });

  @override
  State<ClipboardPopup> createState() => _ClipboardPopupState();
}

class _ClipboardPopupState extends State<ClipboardPopup>
    with SingleTickerProviderStateMixin {
  late TextEditingController _numberController;
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  bool _isDialing = false;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(text: widget.phoneNumber);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _dial() async {
    if (_isDialing) return;
    
    final number = _numberController.text.trim();
    if (number.isEmpty) return;

    setState(() => _isDialing = true);

    // Transform number using dialing rules
    final transformedNumber = DialingRulesService.instance.parseAndTransform(number);

    try {
      // Use engine to place the call - get first registered account
      final accounts = EngineChannel.instance.accounts;
      final accountId = accounts.values.firstWhere(
        (acc) => acc.registrationState.name == 'Registered',
        orElse: () => accounts.values.first,
      ).uuid;
      
      EngineChannel.instance.engine.makeCall(accountId, transformedNumber);

      // Dismiss after short delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    } catch (e) {
      debugPrint('[ClipboardPopup] Error dialing: $e');
      setState(() => _isDialing = false);
    }
  }

  void _dismiss() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _numberController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Number copied to clipboard'),
        duration: Duration(seconds: 1),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.content_paste,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Phone Number Detected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Found in clipboard',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _dismiss,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Number input field
                      TextField(
                        controller: _numberController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'Enter number to dial',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone, color: AppTheme.primary),
                        ),
                        enabled: !_isDialing,
                        keyboardType: TextInputType.phone,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Action buttons
                      Row(
                        children: [
                          // Copy button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isDialing ? null : _copyToClipboard,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Dial button
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _isDialing ? null : _dial,
                              icon: _isDialing
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.call, size: 16),
                              label: Text(_isDialing ? 'Dialing...' : 'Dial'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.callGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
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

/// Overlay entry for showing clipboard popup
class ClipboardPopupOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context, String phoneNumber) {
    // Remove existing entry if any
    dismiss();

    _entry = OverlayEntry(
      builder: (context) => Positioned(
        right: 16,
        bottom: 80, // Above the footer
        child: ClipboardPopup(
          phoneNumber: phoneNumber,
          onDismiss: dismiss,
        ),
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

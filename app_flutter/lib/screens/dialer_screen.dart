import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../core/sip_uri_utils.dart';
import '../core/audio_service.dart';
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
  int? _consultationCallId;
  String? _consultationUri;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    EngineChannel.instance.events.listen(_handleCallEvent);
  }

  void _handleCallEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final payload = (event['payload'] as Map<String, dynamic>?) ?? {};
    
    if (type == 'CallStateChanged') {
      final callId = (payload['call_id'] as num?)?.toInt();
      final state = payload['state'] as String?;
      final direction = payload['direction'] as String?;
      final uri = payload['uri'] as String?;
      
      // Track consultation call: new outgoing call while another is on hold
      if (callId != null && state == 'Ringing' && direction == 'Outgoing') {
        final activeCall = EngineChannel.instance.activeCall;
        if (activeCall != null && activeCall.onHold) {
          setState(() {
            _consultationCallId = callId;
            _consultationUri = uri;
          });
        }
      }
      
      // Update when consultation call is answered (InCall state)
      if (callId != null && state == 'InCall' && callId == _consultationCallId) {
        setState(() => _consultationUri = uri);
      }
      
      // Clear when consultation call ends
      if (state == 'Ended' && callId == _consultationCallId) {
        setState(() {
          _consultationCallId = null;
          _consultationUri = null;
        });
      }
      
      // Clear if original call ends (no longer in consult state)
      if (activeCallEnded(payload) && _consultationCallId != null) {
        setState(() {
          _consultationCallId = null;
          _consultationUri = null;
        });
      }
    }
  }

  bool activeCallEnded(Map<String, dynamic> payload) {
    final state = payload['state'] as String?;
    final callId = (payload['call_id'] as num?)?.toInt();
    final activeCall = EngineChannel.instance.activeCall;
    return state == 'Ended' && activeCall != null && callId == activeCall.callId;
  }

  @override
  void dispose() {
    _uriCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Check if there's a consultation call active.
  bool _hasConsultationCall() => _consultationCallId != null;

  /// Get consultation call display info.
  String? get _consultationDisplay => _consultationUri != null 
      ? SipUriUtils.friendlyName(_consultationUri!) 
      : null;

  void _dialKey(String digit, bool isCallActive) {
    // Local feedback (Spec 6.2)
    HapticFeedback.lightImpact();
    AudioService.instance.playDialTone(digit);

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
      List<AudioDevice> audioDevices) async {
    final raw = _uriCtrl.text.trim();
    if (raw.isEmpty) {
      _showErrorDialog('No Number Entered', 'Please enter a number or URI to dial.');
      return;
    }

    final hasInput = audioDevices.any((d) => d.isInput);
    final hasOutput = audioDevices.any((d) => d.isOutput);

    // Warn about missing audio devices first
    if (!hasInput || !hasOutput) {
      _showAudioDeviceWarning(
        context,
        hasInput: hasInput,
        hasOutput: hasOutput,
        onProceed: () => _dialWithAccountSelection(raw),
      );
      return;
    }

    _dialWithAccountSelection(raw);
  }

  /// Handles account selection and dialing.
  Future<void> _dialWithAccountSelection(String raw) async {
    final selectedAccount = await _selectAccount(context);
    if (selectedAccount == null) return;

    final accountState = EngineChannel.instance.accounts[selectedAccount.uuid];
    if (accountState?.registrationState != RegistrationState.registered) {
      _showErrorDialog(
        'Account Not Registered',
        'The selected account "${selectedAccount.accountName}" is not registered.\n\n'
        'Please check your account settings and server connection.',
      );
      return;
    }

    _executeCall(selectedAccount, raw);
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

    final rc = EngineChannel.instance.engine.makeCall(accountId, uri);
    if (rc != 0) {
      // Handle error codes from Rust EngineErrorCode enum
      String errorMessage;
      String title = 'Call Failed';
      switch (rc) {
        case 7: // MediaNotReady - audio device unavailable
          title = 'Audio Device Unavailable';
          errorMessage = 'Cannot start call - no audio devices detected.\n\n'
              'Please check:\n'
              '• Microphone is connected and enabled\n'
              '• Speakers or headphones are connected\n'
              '• Audio devices are selected in Windows Sound settings';
          break;
        case 6: // NotFound
          errorMessage = 'Account not found or not registered. Please verify your account settings.';
          break;
        case 1: // AlreadyInitialized
        case 2: // NotInitialized
        case 100: // InternalError
        default:
          errorMessage = 'Call failed (error code $rc). '
              'Please check your audio devices and try again.';
      }
      _showErrorDialog(title, errorMessage);
    }
  }

  /// Shows account selection dialog when multiple accounts are registered.
  Future<AccountSchema?> _selectAccount(BuildContext context) async {
    final registeredAccounts = EngineChannel.instance.accounts.values
        .where((a) => a.registrationState == RegistrationState.registered)
        .toList();

    if (registeredAccounts.isEmpty) {
      _showErrorDialog('No Account Available',
          'Please register at least one SIP account before making calls.');
      return null;
    }

    if (registeredAccounts.length == 1) {
      // Convert Account to AccountSchema
      final acc = registeredAccounts.first;
      return AccountSchema()
        ..uuid = acc.uuid
        ..accountName = acc.accountName
        ..displayName = acc.displayName
        ..server = acc.server
        ..username = acc.username
        ..password = '';
    }

    // Multiple accounts - show selection dialog
    return showDialog<AccountSchema>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        icon: const Icon(Icons.sim_card, color: AppTheme.primary, size: 48),
        title: const Text('Select Account',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose which account to use for this call:',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: registeredAccounts.length,
                itemBuilder: (context, index) {
                  final account = registeredAccounts[index];
                  return Card(
                    color: AppTheme.inputFill,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                        child: Text(
                          account.accountName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        account.accountName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${account.username}@${account.server}',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, account),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        icon: const Icon(Icons.error, color: AppTheme.errorRed, size: 48),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showAudioDeviceWarning(
    BuildContext context, {
    required bool hasInput,
    required bool hasOutput,
    required VoidCallback onProceed,
  }) {
    final missingDevices = <String>[];
    if (!hasInput) missingDevices.add('Microphone');
    if (!hasOutput) missingDevices.add('Speaker');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        icon: const Icon(Icons.warning, color: AppTheme.warningAmber, size: 48),
        title: const Text('Audio Device Warning',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Missing audio devices:',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...missingDevices.map((d) =>
                Text('• $d', style: const TextStyle(color: AppTheme.textSecondary))),
            const SizedBox(height: 16),
            const Text(
              'The call will use null audio devices (no sound). '
              'Connect audio devices and configure them in Settings.',
              style: TextStyle(color: AppTheme.textSecondary),
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
            onPressed: () {
              Navigator.pop(context);
              onProceed();
            },
            child: const Text('Proceed Anyway',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  /// Shows transfer dialog with destination and transfer type selection.
  void _showTransferDialog(ActiveCall call) {
    // If there's a consultation call, show complete transfer dialog instead
    if (_hasConsultationCall()) {
      _showCompleteTransferDialog(call);
      return;
    }

    final transferCtrl = TextEditingController();
    final transferFocusNode = FocusNode();
    bool isConsultTransfer = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          icon: const Icon(Icons.phone_forwarded,
              color: AppTheme.primary, size: 48),
          title: const Text('Transfer Call',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transfer this call to:',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: transferCtrl,
                  focusNode: transferFocusNode,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'sip:user@domain or extension',
                    hintStyle: const TextStyle(color: AppTheme.textTertiary),
                    filled: true,
                    fillColor: AppTheme.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.phone_forwarded,
                        color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Transfer Type:',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    ListTile(
                      leading: Radio<bool>(
                        value: false,
                        groupValue: isConsultTransfer,
                        onChanged: (value) {
                          setDialogState(() => isConsultTransfer = value!);
                        },
                        activeColor: AppTheme.primary,
                      ),
                      title: const Text('Blind Transfer',
                          style: TextStyle(color: AppTheme.textPrimary)),
                      subtitle: const Text('Transfer immediately without consulting',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    ListTile(
                      leading: Radio<bool>(
                        value: true,
                        groupValue: isConsultTransfer,
                        onChanged: (value) {
                          setDialogState(() => isConsultTransfer = value!);
                        },
                        activeColor: AppTheme.primary,
                      ),
                      title: const Text('Consult Transfer',
                          style: TextStyle(color: AppTheme.textPrimary)),
                      subtitle: const Text('Speak to target first, then transfer',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                transferCtrl.dispose();
                transferFocusNode.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                if (transferCtrl.text.trim().isNotEmpty) {
                  _executeTransfer(call, transferCtrl.text.trim(), isConsultTransfer);
                  Navigator.pop(context);
                }
              },
              child: const Text('Transfer',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    ).then((_) {
      transferCtrl.dispose();
      transferFocusNode.dispose();
    });
  }

  /// Shows dialog to complete consult transfer when consultation call is active.
  void _showCompleteTransferDialog(ActiveCall heldCall) {
    final consultationId = _consultationCallId;
    final consultationTarget = _consultationDisplay;
    if (consultationId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        icon: const Icon(Icons.check_circle,
            color: AppTheme.callGreen, size: 48),
        title: const Text('Complete Transfer',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complete the attended transfer?',
              style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (consultationTarget != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transfer to:',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            consultationTarget,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'This will connect the held call to ${consultationTarget ?? 'the consultation target'} and end your consultation call.',
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _completeTransfer(heldCall);
            },
            icon: const Icon(Icons.phone_forwarded, size: 18),
            label: const Text('Complete Transfer'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows conference dialog to add a participant.
  void _showConferenceDialog(ActiveCall call) {
    // If there's a consultation call, show join conference dialog
    if (_hasConsultationCall()) {
      _joinConference(call);
      return;
    }

    final conferenceCtrl = TextEditingController();
    final conferenceFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        icon: const Icon(Icons.groups,
            color: AppTheme.primary, size: 48),
        title: const Text('Add to Conference',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add this participant to the call:',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: conferenceCtrl,
              focusNode: conferenceFocusNode,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'sip:user@domain or extension',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.groups,
                    color: AppTheme.primary),
              ),
              onSubmitted: (_) {
                if (conferenceCtrl.text.trim().isNotEmpty) {
                  _executeConference(call, conferenceCtrl.text.trim());
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'This will put the current call on hold and dial the participant. Once they answer, you can create a 3-way conference.',
              style: TextStyle(
                  color: AppTheme.textTertiary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              conferenceCtrl.dispose();
              conferenceFocusNode.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (conferenceCtrl.text.trim().isNotEmpty) {
                _executeConference(call, conferenceCtrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add Participant',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    ).then((_) {
      conferenceCtrl.dispose();
      conferenceFocusNode.dispose();
    });
  }

  void _executeTransfer(ActiveCall call, String destUri, bool isConsult) {
    // Build proper SIP URI if needed
    String uri = destUri;
    if (!destUri.contains(':')) {
      // Try to get domain from account
      final account = EngineChannel.instance.accounts[call.accountId];
      if (account != null && account.server.isNotEmpty) {
        uri = 'sip:$destUri@${account.server}';
      } else {
        uri = 'sip:$destUri';
      }
    } else if (!destUri.startsWith('sip:') &&
        !destUri.startsWith('sips:')) {
      uri = 'sip:$destUri';
    }

    if (isConsult) {
      // Consult transfer: put current call on hold, dial target
      final result = EngineChannel.instance.startAttendedXfer(call.callId, uri);
      if (result >= 0) {
        // Store consultation call ID
        setState(() => _consultationCallId = result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calling $uri for consultation...'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        _showErrorDialog('Transfer Failed', _getTransferErrorMessage(result));
      }
    } else {
      // Blind transfer: transfer immediately
      final result = EngineChannel.instance.transferCall(call.callId, uri);
      if (result == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transferring call to $uri...'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        _showErrorDialog('Transfer Failed', _getTransferErrorMessage(result));
      }
    }
  }

  String _getTransferErrorMessage(int errorCode) {
    switch (errorCode) {
      case -1: return 'Engine not initialized. Please try again.';
      case 6: return 'Call not found. The call may have ended.';
      case 7: return 'Media not ready. Check audio device settings.';
      case 100: return 'Internal error. Please try again.';
      default: return 'Transfer failed (error code: $errorCode).';
    }
  }

  void _executeConference(ActiveCall call, String destUri) {
    // Build proper SIP URI if needed
    String uri = destUri;
    if (!destUri.contains(':')) {
      final account = EngineChannel.instance.accounts[call.accountId];
      if (account != null && account.server.isNotEmpty) {
        uri = 'sip:$destUri@${account.server}';
      } else {
        uri = 'sip:$destUri';
      }
    } else if (!destUri.startsWith('sip:') &&
        !destUri.startsWith('sips:')) {
      uri = 'sip:$destUri';
    }

    // Put current call on hold and dial the participant
    final result = EngineChannel.instance.startAttendedXfer(call.callId, uri);
    if (result >= 0) {
      setState(() => _consultationCallId = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling $uri to add to conference...'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _showErrorDialog('Conference Failed', _getTransferErrorMessage(result));
    }
  }


  /// Complete a consult transfer - transfer the held call to the consultation target.
  void _completeTransfer(ActiveCall heldCall) {
    final consultationId = _consultationCallId;
    if (consultationId == null) return;

    final result = EngineChannel.instance.completeXfer(heldCall.callId, consultationId);
    
    if (result == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Completing transfer...'),
            ],
          ),
          backgroundColor: AppTheme.callGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      setState(() {
        _consultationCallId = null;
        _consultationUri = null;
      });
    } else {
      _showErrorDialog('Transfer Failed', _getTransferErrorMessage(result));
    }
  }

  /// Join the held call and active call into a conference.
  void _joinConference(ActiveCall heldCall) {
    final consultationId = _consultationCallId;
    final consultationTarget = _consultationDisplay;
    if (consultationId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        icon: const Icon(Icons.groups,
            color: AppTheme.primary, size: 48),
        title: const Text('Join Conference',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a 3-way conference?',
              style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (consultationTarget != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_add, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add to conference:',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            consultationTarget,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'This will merge all parties into a single conference call.',
              style: TextStyle(
                  color: AppTheme.textTertiary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _executeMergeConference(heldCall.callId, consultationId);
            },
            icon: const Icon(Icons.groups, size: 18),
            label: const Text('Join Conference'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _executeMergeConference(int callAId, int callBId) {
    final result = EngineChannel.instance.mergeConference(callAId, callBId);

    if (result == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Joining calls into conference...'),
            ],
          ),
          backgroundColor: AppTheme.callGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      setState(() {
        _consultationCallId = null;
        _consultationUri = null;
      });
    } else {
      _showErrorDialog('Conference Failed', _getTransferErrorMessage(result));
    }
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

                    // 2. Active Call Panel (expands to fill space)
                    if (activeCall != null)
                      Expanded(
                        child: _ActiveCallCard(
                          call: activeCall,
                          stats: stats,
                          onHangup: _hangup,
                          onTransfer: () => _showTransferDialog(activeCall),
                          onConference: () => _showConferenceDialog(activeCall),
                          hasConsultationCall: _hasConsultationCall(),
                          consultationDisplay: _consultationDisplay,
                        ),
                      )
                    else
                      Expanded(child: _buildReadyIndicator()),

                    const SizedBox(height: 10),

                    // 3. Dialing Input
                    _buildDialInput(),

                    const SizedBox(height: 10),

                    // 4. Integrated Numpad
                    _buildNumpadGrid(activeCall),

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
      decoration: AppTheme.glassCard(
        borderRadius: 10,
        color: AppTheme.surfaceCard.withValues(alpha: 0.4),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_enabled,
                size: 32, color: AppTheme.callGreen.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text('READY',
                style: TextStyle(
                  color: AppTheme.textTertiary.withValues(alpha: 0.7),
                  fontSize: 12,
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
  final VoidCallback onTransfer;
  final VoidCallback onConference;
  final bool hasConsultationCall;
  final String? consultationDisplay;

  const _ActiveCallCard({
    required this.call,
    this.stats,
    required this.onHangup,
    required this.onTransfer,
    required this.onConference,
    this.hasConsultationCall = false,
    this.consultationDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCard(
        color: hasConsultationCall 
            ? AppTheme.primary.withValues(alpha: 0.05)
            : AppTheme.accent.withValues(alpha: 0.08),
        borderColor: hasConsultationCall
            ? AppTheme.primary.withValues(alpha: 0.3)
            : AppTheme.accent.withValues(alpha: 0.25),
      ),
      child: Column(
        children: [
          // Consultation status banner
          if (hasConsultationCall) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.15),
                    AppTheme.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_callback,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Consultation Call',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          consultationDisplay ?? 'Calling...',
                          style: TextStyle(
                            color: AppTheme.primary.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.callGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.callGreen.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.callGreen,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: AppTheme.callGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Main call info
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
                    Row(
                      children: [
                        Text(call.state.label,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.accent.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500)),
                        if (call.onHold) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.warningAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppTheme.warningAmber.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'On Hold',
                              style: TextStyle(
                                color: AppTheme.warningAmber,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
          // Action buttons
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
                icon: hasConsultationCall ? Icons.check_circle : Icons.phone_forwarded,
                label: hasConsultationCall ? 'COMPLETE' : 'TRANSFER',
                active: false,
                enabled: call.state != CallState.ringing,
                onTap: onTransfer,
              ),
              _CallControlButton(
                icon: hasConsultationCall ? Icons.groups : Icons.groups,
                label: hasConsultationCall ? 'JOIN' : 'CONFERENCE',
                active: false,
                enabled: call.state != CallState.ringing,
                onTap: onConference,
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../core/sip_uri_utils.dart';
import '../core/audio_service.dart';
import '../core/engine_channel.dart';
import '../core/account_service.dart';
import '../core/recording_service.dart';
import '../models/account_schema.dart';
import '../models/account.dart';
import '../models/audio_device.dart';
import '../models/call.dart';
import '../models/media_stats.dart';
import '../providers/engine_provider.dart';
import '../providers/dialer_ui_provider.dart';
import '../widgets/gradient_action_button.dart';
import 'recordings_screen.dart';

final selectedAccountProvider = Provider<AccountSchema?>((ref) {
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
    RecordingService.instance.addListener(_handleRecordingChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    RecordingService.instance.removeListener(_handleRecordingChanged);
    _uriCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleRecordingChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _navigateToRecordings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecordingsScreen()),
    );
  }

  /// Check if there's a consultation call active.
  bool _hasConsultationCall() => ref.read(dialerUiProvider).hasConsultationCall;

  /// Get consultation call display info.
  String? get _consultationDisplay =>
      ref.read(dialerUiProvider).consultationDisplay;

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
      _showErrorDialog(
          'No Number Entered', 'Please enter a number or URI to dial.');
      return;
    }

    final hasInput = audioDevices.any((d) => d.isInput);
    final hasOutput = audioDevices.any((d) => d.isOutput);
    final selectedInputId = EngineChannel.instance.selectedInputId;
    final selectedOutputId = EngineChannel.instance.selectedOutputId;
    AudioDevice? selectedInput;
    AudioDevice? selectedOutput;
    for (final device in audioDevices) {
      if (selectedInput == null &&
          device.id == selectedInputId &&
          device.isInput) {
        selectedInput = device;
      }
      if (selectedOutput == null &&
          device.id == selectedOutputId &&
          device.isOutput) {
        selectedOutput = device;
      }
    }

    final registeredCount = EngineChannel.instance.accounts.values
        .where((a) => a.registrationState == RegistrationState.registered)
        .length;
    debugPrint(
      '[Dialer] Call preflight raw="$raw" selectedAccount=${activeAccount?.uuid ?? "<none>"} '
      'activeAccountState=${activeAccountState?.registrationState.name ?? "<none>"} '
      'registered_accounts=$registeredCount audio_entries=${audioDevices.length} '
      'has_input=$hasInput has_output=$hasOutput '
      'selected_input=$selectedInputId(${selectedInput?.name ?? "<missing>"}) '
      'selected_output=$selectedOutputId(${selectedOutput?.name ?? "<missing>"})',
    );

    // Warn about missing audio devices first
    if (!hasInput || !hasOutput) {
      _showAudioDeviceWarning(
        context,
        hasInput: hasInput,
        hasOutput: hasOutput,
        onProceed: () => _dialWithSelectedAccount(activeAccount, raw),
      );
      return;
    }

    _dialWithSelectedAccount(activeAccount, raw);
  }

  void _dialWithSelectedAccount(AccountSchema? selectedAccount, String raw) {
    if (selectedAccount == null) {
      _showErrorDialog('No Account Selected',
          'Select a SIP account from the dialer header before placing a call.');
      return;
    }

    final accountState = EngineChannel.instance.accounts[selectedAccount.uuid];
    if (accountState == null) {
      _showErrorDialog(
        'Account Unavailable',
        'The selected account "${selectedAccount.accountName}" is not loaded in the engine.\n\n'
            'Try re-enabling the account from the Accounts page.',
      );
      return;
    }
    if (accountState.registrationState != RegistrationState.registered) {
      _showErrorDialog(
        'Account Not Registered',
        'The selected account "${selectedAccount.accountName}" is not registered.\n\n'
            'Please check your account settings and server connection.',
      );
      return;
    }
    if (selectedAccount.username.trim().isEmpty ||
        selectedAccount.server.trim().isEmpty) {
      _showErrorDialog(
        'Incomplete Account',
        'The selected account is missing username or server, so it cannot place calls.',
      );
      return;
    }

    _executeCall(selectedAccount, raw);
  }

  void _executeCall(AccountSchema activeAccount, String raw) {
    final accountId = activeAccount.uuid;

    final uri = raw.trim();
    if (uri.isEmpty) {
      debugPrint('[Dialer] _executeCall aborted: empty dial target');
      return;
    }

    debugPrint('[Dialer] makeCall account=$accountId target="$uri"');
    final rc = EngineChannel.instance.engine.makeCall(accountId, uri);
    debugPrint('[Dialer] makeCall rc=$rc');
    if (rc != 0) {
      if (rc == 7) {
        // MediaNotReady - offer bypass
        _showAudioDeviceWarning(
          context,
          hasInput: false,
          hasOutput: false,
          onProceed: () {
            // This is complex - engine already failed.
            // We'd need a "force" flag in makeCall or just tell user to try again
            // and maybe the engine will use the system defaults now that we've added that fallback.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Please check audio settings and try dialing again.')),
            );
          },
        );
        return;
      }

      String errorMessage;
      String title = 'Call Failed';
      bool showSettingsButton = true;

      switch (rc) {
        case 6: // NotFound
          errorMessage =
              'Account not found or not registered. Please verify your account settings.';
          break;
        case 100: // InternalError (now includes network errors)
          title = 'Network or System Error';
          errorMessage =
              'The call could not be started due to a network or internal error (code $rc).\n\n'
              'Common causes:\n'
              '• Network is unreachable (check WiFi/Ethernet)\n'
              '• Server is not responding\n'
              '• Account registration lost';
          break;
        default:
          errorMessage = 'Call failed (error code $rc). '
              'Please check your network and audio devices.';
      }

      _showErrorDialog(title, errorMessage, showSettings: showSettingsButton);
    }
  }

  void _showErrorDialog(String title, String message,
      {bool showSettings = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        icon: const Icon(Icons.error, color: AppTheme.errorRed, size: 48),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(message,
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          if (showSettings)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Switch to Settings tab (index 2 usually)
                // Note: The parent scaffold is controlled by NavigationBar
                // This might not work perfectly without a callback to main,
                // but we can try to push the settings page or just close.
                // For now, let's just show a snackbar or close.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Go to Settings > Audio to configure devices')),
                );
              },
              child: const Text('Check Settings',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
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
            ...missingDevices.map((d) => Text('• $d',
                style: const TextStyle(color: AppTheme.textSecondary))),
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
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                RadioGroup<bool>(
                  groupValue: isConsultTransfer,
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => isConsultTransfer = value);
                  },
                  child: const Column(
                    children: [
                      RadioListTile<bool>(
                        value: false,
                        title: Text('Blind Transfer',
                            style: TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text(
                            'Transfer immediately without consulting',
                            style: TextStyle(
                                color: AppTheme.textTertiary, fontSize: 11)),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primary,
                      ),
                      RadioListTile<bool>(
                        value: true,
                        title: Text('Consult Transfer',
                            style: TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text('Speak to target first, then transfer',
                            style: TextStyle(
                                color: AppTheme.textTertiary, fontSize: 11)),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                if (transferCtrl.text.trim().isNotEmpty) {
                  _executeTransfer(
                      call, transferCtrl.text.trim(), isConsultTransfer);
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
    final consultationId = ref.read(dialerUiProvider).consultationCallId;
    final consultationTarget = _consultationDisplay;
    if (consultationId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        icon:
            const Icon(Icons.check_circle, color: AppTheme.callGreen, size: 48),
        title: const Text('Complete Transfer',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complete the attended transfer?',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
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
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
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
        icon: const Icon(Icons.groups, color: AppTheme.primary, size: 48),
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
                prefixIcon: const Icon(Icons.groups, color: AppTheme.primary),
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
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
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
    } else if (!destUri.startsWith('sip:') && !destUri.startsWith('sips:')) {
      uri = 'sip:$destUri';
    }

    if (isConsult) {
      // Consult transfer: put current call on hold, dial target
      final result = EngineChannel.instance.startAttendedXfer(call.callId, uri);
      if (result >= 0) {
        // Store consultation call ID
        ref.read(dialerUiProvider.notifier).setConsultationCallId(result);
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
      case -1:
        return 'Engine not initialized. Please try again.';
      case 6:
        return 'Call not found. The call may have ended.';
      case 7:
        return 'Media not ready. Check audio device settings.';
      case 100:
        return 'Internal error. Please try again.';
      default:
        return 'Transfer failed (error code: $errorCode).';
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
    } else if (!destUri.startsWith('sip:') && !destUri.startsWith('sips:')) {
      uri = 'sip:$destUri';
    }

    // Put current call on hold and dial the participant
    final result = EngineChannel.instance.startAttendedXfer(call.callId, uri);
    if (result >= 0) {
      ref.read(dialerUiProvider.notifier).setConsultationCallId(result);
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
    final consultationId = ref.read(dialerUiProvider).consultationCallId;
    if (consultationId == null) return;

    final result =
        EngineChannel.instance.completeXfer(heldCall.callId, consultationId);

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

      ref.read(dialerUiProvider.notifier).clearConsultation();
    } else {
      _showErrorDialog('Transfer Failed', _getTransferErrorMessage(result));
    }
  }

  /// Join the held call and active call into a conference.
  void _joinConference(ActiveCall heldCall) {
    final consultationId = ref.read(dialerUiProvider).consultationCallId;
    final consultationTarget = _consultationDisplay;
    if (consultationId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        icon: const Icon(Icons.groups, color: AppTheme.primary, size: 48),
        title: const Text('Join Conference',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a 3-way conference?',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
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
                    const Icon(Icons.person_add,
                        color: AppTheme.primary, size: 20),
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
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
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

      ref.read(dialerUiProvider.notifier).clearConsultation();
    } else {
      _showErrorDialog('Conference Failed', _getTransferErrorMessage(result));
    }
  }

  void _hangup() => EngineChannel.instance.engine.hangup();

  Future<void> _toggleRecording() async {
    final activeCall = EngineChannel.instance.activeCall;
    if (activeCall == null) return;

    final wasRecording =
        RecordingService.instance.isRecordingForCall(activeCall.callId);
    final ok =
        await RecordingService.instance.toggleRecordingForCall(activeCall.callId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (wasRecording ? 'Recording stopped' : 'Recording started')
              : (wasRecording
                  ? 'Failed to stop recording'
                  : 'Failed to start recording'),
        ),
      ),
    );
    setState(() {});
  }

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
    final accountService = ref.watch(accountServiceProvider);
    final activeAccount = accountService.getSelectedAccount();
    final allAccounts = accountService.getAllAccounts();
    final activeCall = ref.watch(activeCallProvider);
    final stats = ref.watch(activeCallMediaStatsProvider);
    final dialerUi = ref.watch(dialerUiProvider);

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
              _call(activeAccount, activeAccountState, audioDevices);
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
          child: Builder(
            builder: (context) {
              final audioDevices = ref.watch(audioDevicesProvider);
              final activeAccountState = ref.watch(activeAccountProvider);
              return Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // 1. Compact Header
                    _buildCompactHeader(activeAccount, allAccounts),
                    const SizedBox(height: 10),

                    // 2. Active Call Panel (expands to fill space)
                    if (activeCall != null)
                      Expanded(
                        flex: 2,
                        child: _ActiveCallCard(
                          call: activeCall,
                          stats: stats,
                          onHangup: _hangup,
                          onRecordToggle: _toggleRecording,
                          onTransfer: () => _showTransferDialog(activeCall),
                          onConference: () => _showConferenceDialog(activeCall),
                          hasConsultationCall: dialerUi.hasConsultationCall,
                          consultationDisplay: dialerUi.consultationDisplay,
                          isRecording: RecordingService.instance
                              .isRecordingForCall(activeCall.callId),
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
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(
      AccountSchema? account, List<AccountSchema> allAccounts) {
    final selectableAccounts =
        allAccounts.where((acct) => acct.isEnabled).toList(growable: false);
    final selectedValue = account != null &&
            selectableAccounts.any((acct) => acct.uuid == account.uuid)
        ? account.uuid
        : null;

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
            child: selectableAccounts.length <= 1
                ? Text(
                    _dialerHeaderAccountLabel(account),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedValue,
                      isExpanded: true,
                      dropdownColor: AppTheme.surfaceCard,
                      iconEnabledColor: AppTheme.primary,
                      hint: const Text(
                        'Select account',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      items: selectableAccounts.map((acct) {
                        final regState = EngineChannel
                                .instance.accounts[acct.uuid]?.registrationState ??
                            RegistrationState.unregistered;
                        final statusText = switch (regState) {
                          RegistrationState.registered => 'Registered',
                          RegistrationState.registering => 'Registering',
                          RegistrationState.failed => 'Failed',
                          RegistrationState.unregistered => 'Offline',
                        };
                        return DropdownMenuItem<String>(
                          value: acct.uuid,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dialerHeaderAccountLabel(acct),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: regState == RegistrationState.registered
                                      ? AppTheme.callGreen
                                      : AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        await ref
                            .read(accountServiceProvider)
                            .setSelectedAccount(value);
                      },
                    ),
                  ),
          ),
          // Recordings button
          IconButton(
            icon: const Icon(Icons.library_music, size: 20),
            color: AppTheme.textSecondary,
            onPressed: _navigateToRecordings,
            tooltip: 'Recordings',
            padding: const EdgeInsets.all(4),
          ),
          const SizedBox(width: 4),
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

  String _dialerHeaderAccountLabel(AccountSchema? account) {
    if (account == null) return 'No Active Account';
    final accountName = account.accountName.trim();
    if (accountName.isNotEmpty) return accountName;
    final displayName = account.displayName.trim();
    if (displayName.isNotEmpty) return displayName;
    final username = account.username.trim();
    if (username.isNotEmpty) return username;
    return 'No Active Account';
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
    return GradientActionButton(
      icon: isCall ? Icons.call_end : Icons.call,
      label: isCall ? 'HANG UP (Esc)' : 'DIAL (Enter)',
      gradient:
          isCall ? AppTheme.hangupButtonGradient : AppTheme.callButtonGradient,
      glowColor: isCall ? AppTheme.hangupRed : AppTheme.callGreen,
      onTap: isCall
          ? _hangup
          : () => _call(account, activeAccountState, audioDevices),
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
  final VoidCallback onRecordToggle;
  final VoidCallback onTransfer;
  final VoidCallback onConference;
  final bool hasConsultationCall;
  final String? consultationDisplay;
  final bool isRecording;

  const _ActiveCallCard({
    required this.call,
    this.stats,
    required this.onHangup,
    required this.onRecordToggle,
    required this.onTransfer,
    required this.onConference,
    this.hasConsultationCall = false,
    this.consultationDisplay,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    final minCardHeight = hasConsultationCall ? 250.0 : 200.0;
    return Container(
      constraints: BoxConstraints(minHeight: minCardHeight),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCard(
        color: hasConsultationCall
            ? AppTheme.primary.withValues(alpha: 0.05)
            : AppTheme.accent.withValues(alpha: 0.08),
        borderColor: hasConsultationCall
            ? AppTheme.primary.withValues(alpha: 0.3)
            : AppTheme.accent.withValues(alpha: 0.25),
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minCardHeight - 28),
          child: Column(
            children: [
              // Consultation status banner
              if (hasConsultationCall) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                                    color:
                                        AppTheme.accent.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500)),
                            if (call.onHold) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningAmber
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppTheme.warningAmber
                                        .withValues(alpha: 0.4),
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
                    onHold: call.onHold,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Action buttons (keep a strict minimum height to avoid clipping)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Row(
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
                      icon: isRecording
                          ? Icons.stop_circle_outlined
                          : Icons.fiber_manual_record,
                      label: isRecording ? 'STOP REC' : 'RECORD',
                      active: isRecording,
                      activeColor: AppTheme.errorRed,
                      enabled: call.state != CallState.ringing,
                      onTap: onRecordToggle,
                    ),
                    _CallControlButton(
                      icon: hasConsultationCall
                          ? Icons.check_circle
                          : Icons.phone_forwarded,
                      label: hasConsultationCall ? 'COMPLETE' : 'TRANSFER',
                      active: false,
                      enabled: call.state != CallState.ringing,
                      onTap: onTransfer,
                    ),
                    _CallControlButton(
                      icon: Icons.groups,
                      label: hasConsultationCall ? 'JOIN' : 'CONFERENCE',
                      active: false,
                      enabled: call.state != CallState.ringing,
                      onTap: onConference,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
  final Color? activeColor;
  final bool enabled;
  final VoidCallback onTap;
  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.active,
    this.activeColor,
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
    final selectedColor = activeColor ?? AppTheme.warningAmber;
    final color = active ? selectedColor : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            active ? selectedColor.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? selectedColor.withValues(alpha: 0.3)
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
  final bool onHold;

  const _TimerWidget({
    this.startTime,
    this.accumulatedSeconds = 0,
    this.lastResumedAt,
    this.onHold = false,
  });

  @override
  State<_TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<_TimerWidget> {
  Timer? _timer;
  Duration _duration = Duration.zero;
  int _baseAccumulatedSeconds = 0;
  DateTime? _resumeAt;

  @override
  void initState() {
    super.initState();
    _syncStateFromWidget(force: true);
    _startTimer();
  }

  @override
  void didUpdateWidget(_TimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onHold != widget.onHold &&
        widget.lastResumedAt == null &&
        widget.startTime != null) {
      if (widget.onHold) {
        _updateDuration();
        _baseAccumulatedSeconds = _duration.inSeconds;
        _resumeAt = null;
      } else {
        _resumeAt = DateTime.now();
      }
    }

    if (oldWidget.startTime != widget.startTime ||
        oldWidget.lastResumedAt != widget.lastResumedAt ||
        oldWidget.accumulatedSeconds != widget.accumulatedSeconds) {
      _syncStateFromWidget();
    }

    if (oldWidget.startTime != widget.startTime ||
        oldWidget.lastResumedAt != widget.lastResumedAt ||
        oldWidget.accumulatedSeconds != widget.accumulatedSeconds ||
        oldWidget.onHold != widget.onHold) {
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

  void _syncStateFromWidget({bool force = false}) {
    if (widget.startTime == null) {
      _baseAccumulatedSeconds = 0;
      _resumeAt = null;
      return;
    }

    if (widget.lastResumedAt != null) {
      _baseAccumulatedSeconds = widget.accumulatedSeconds;
      _resumeAt = widget.lastResumedAt;
      return;
    }

    if (widget.accumulatedSeconds > 0) {
      _baseAccumulatedSeconds = widget.accumulatedSeconds;
      _resumeAt = widget.onHold ? null : (force ? DateTime.now() : _resumeAt);
      return;
    }

    // Fallback for early call phase where backend doesn't expose timing fields yet.
    if (force || _resumeAt == null) {
      _baseAccumulatedSeconds = 0;
      _resumeAt = widget.onHold ? null : widget.startTime;
    }
  }

  void _updateDuration() {
    setState(() {
      if (widget.startTime == null) {
        _duration = Duration.zero;
      } else if (_resumeAt != null) {
        _duration = Duration(seconds: _baseAccumulatedSeconds) +
            DateTime.now().difference(_resumeAt!);
      } else {
        _duration = Duration(seconds: _baseAccumulatedSeconds);
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

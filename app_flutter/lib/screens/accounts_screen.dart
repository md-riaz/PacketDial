import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../core/account_service.dart';
import '../models/account.dart';
import '../models/account_schema.dart';
import '../widgets/empty_state.dart';
import '../providers/engine_provider.dart';
import 'account_setup_page.dart';

final accountRegisteringProvider =
    StateProvider.family<bool, String>((ref, id) {
  return false;
});

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  void _showAccountSetup([AccountSchema? existing]) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => AccountSetupPage(existing: existing),
      ),
    )
        .then((saved) {
      if (saved == true && mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountService = ref.watch(accountServiceProvider);
    final accounts = accountService.getAllAccounts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            tooltip: 'Add Account',
            onPressed: () => _showAccountSetup(),
          ),
        ],
      ),
      body: accounts.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: accounts.length,
              itemBuilder: (_, i) =>
                  _AccountCard(account: accounts[i], parent: this),
            ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.person_add_outlined,
      title: 'No SIP Accounts',
      subtitle: 'Tap + to add your first SIP account',
      actionLabel: 'Add Account',
      onAction: () => _showAccountSetup(),
    );
  }
}

// ── Account Card ─────────────────────────────────────────────────────────
class _AccountCard extends ConsumerStatefulWidget {
  final AccountSchema account;
  final _AccountsScreenState parent;
  const _AccountCard({required this.account, required this.parent});

  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  void _showActionsMenu() {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + renderBox.size.width - 40,
        offset.dy + 10,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: AppTheme.errorRed),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        widget.parent._showAccountSetup(widget.account);
      } else if (value == 'delete') {
        _deleteAccount();
      }
    });
  }

  Future<void> _toggleRegistration(bool? value) async {
    final isRegistering =
        ref.read(accountRegisteringProvider(widget.account.uuid));
    if (isRegistering || value == null) return;
    ref.read(accountRegisteringProvider(widget.account.uuid).notifier).state =
        true;

    try {
      final service = ref.read(accountServiceProvider);

      // First persist the enabled state
      await service.setAccountEnabled(widget.account.uuid, value);

      if (value == true) {
        // Try to register this account
        debugPrint(
            '[AccountsScreen] Starting registration preflight for ${widget.account.uuid}');
        final result = await service.tryRegister(
          username: widget.account.username,
          password: widget.account.password,
          server: widget.account.server,
          transport: widget.account.transport,
          domain: widget.account.domain,
          proxy: widget.account.sipProxy,
        );

        if (!result.success) {
          // Show error dialog
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Registration Failed'),
              content: Text(
                'Failed to register "${widget.account.accountName}".\n\n'
                '${result.errorReason}',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          // Reset switch to off state happens in finally
          return;
        }

        final rc = service.register(widget.account);
        debugPrint('[AccountsScreen] register(${widget.account.uuid}) rc=$rc');
        if (rc != 0) {
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Registration Command Failed'),
              content: Text(
                'Account "${widget.account.accountName}" could not be registered.\n\n'
                'Engine returned rc=$rc.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }

        // Keep a default account selected for UI fallback if none exists yet.
        final selected = service.getSelectedAccount();
        if (selected == null) {
          await service.setSelectedAccount(widget.account.uuid);
        }
      } else {
        final rc = service.unregister(widget.account.uuid);
        debugPrint(
            '[AccountsScreen] unregister(${widget.account.uuid}) rc=$rc');
        if (rc != 0 && rc != 6) {
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Unregister Failed'),
              content: Text(
                'Account "${widget.account.accountName}" could not be unregistered.\n\n'
                'Engine returned rc=$rc.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Show error dialog
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Registration Error'),
          content: Text(
            'An error occurred while registering "${widget.account.accountName}".\n\n'
            '$e',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        ref
            .read(accountRegisteringProvider(widget.account.uuid).notifier)
            .state = false;
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete "${widget.account.accountName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(false);
              }
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(accountServiceProvider).deleteAccount(widget.account.uuid);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Listen for engine-level registration changes
    final engineAccount = ref.watch(engineAccountProvider(widget.account.uuid));
    final registrationState =
        engineAccount?.registrationState ?? RegistrationState.unregistered;

    // 2. Listen for local persistence updates
    final isSelected = widget.account.isSelected;
    final isEnabled = widget.account.isEnabled;

    // 3. Determine dynamic colors and status text
    final statusColor = switch (registrationState) {
      RegistrationState.registered => AppTheme.callGreen,
      RegistrationState.registering => AppTheme.warningAmber,
      RegistrationState.failed => AppTheme.errorRed,
      _ => AppTheme.textTertiary,
    };

    String statusLabel = registrationState.label;
    if (registrationState == RegistrationState.failed &&
        engineAccount?.failureReason != null &&
        engineAccount!.failureReason.isNotEmpty) {
      statusLabel = 'Failed: ${engineAccount.failureReason}';
    }

    return GestureDetector(
      onTap: () => widget.parent._showAccountSetup(widget.account),
      onLongPress: _showActionsMenu,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.callGreen.withValues(alpha: 0.3)
                : AppTheme.border.withValues(alpha: 0.4),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.callGreen.withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with status indicator
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          widget.account.accountName.isNotEmpty
                              ? widget.account.accountName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    if (isEnabled)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.surfaceCard, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                              )
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Account info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.account.accountName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.account.username}@${widget.account.server}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isEnabled) ...[
                        const SizedBox(height: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Switch toggle
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isEnabled,
                    onChanged: (ref.watch(accountRegisteringProvider(
                                widget.account.uuid)) ||
                            registrationState == RegistrationState.registering)
                        ? null
                        : _toggleRegistration,
                    activeThumbColor: Colors.white,
                    activeTrackColor: statusColor,
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

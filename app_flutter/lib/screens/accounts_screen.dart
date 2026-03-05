import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../core/account_service.dart';
import '../models/account_schema.dart';
import '../providers/engine_provider.dart';
import '../core/multi_window/controllers/account_setup_controller.dart';

final accountsListProvider = FutureProvider<List<AccountSchema>>((ref) {
  return ref.watch(accountServiceProvider).getAllAccounts();
});

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  void _showAccountDialog([AccountSchema? existing]) {
    ref.read(accountSetupControllerProvider).showWindow(existing);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);

    // Simple way to listen to global reg updates and refresh local UI list
    ref.listen(engineEventsProvider, (prev, next) {
      if (next.value?['type'] == 'RegistrationStateChanged') {
        ref.invalidate(accountsListProvider);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            tooltip: 'Add Account',
            onPressed: () => _showAccountDialog(),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) => accounts.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: accounts.length,
                itemBuilder: (_, i) =>
                    _AccountCard(account: accounts[i], parent: this),
              ),
        loading: () => Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation(AppTheme.primary.withValues(alpha: 0.6)),
          ),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppTheme.errorRed)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.person_add_outlined,
                size: 48, color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          const Text('No SIP Accounts',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text('Tap + to add your first SIP account',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textTertiary.withValues(alpha: 0.7))),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _showAccountDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Account'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account Card ─────────────────────────────────────────────────────────
class _AccountCard extends ConsumerWidget {
  final AccountSchema account;
  final _AccountsScreenState parent;
  const _AccountCard({required this.account, required this.parent});

  Color _statusColor(AccountSchema a) {
    if (a.isSelected) return AppTheme.callGreen;
    return AppTheme.textTertiary;
  }

  String _statusLabel(AccountSchema a) {
    if (a.isSelected) return 'Active';
    return 'Inactive';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = account.isSelected;
    final statusColor = _statusColor(account);

    return Container(
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
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => parent._showAccountDialog(account),
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
                          account.accountName.isNotEmpty
                              ? account.accountName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppTheme.surfaceCard, width: 2),
                          boxShadow: AppTheme.glowShadow(statusColor, blur: 4),
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
                        account.accountName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        account.displayName.isNotEmpty
                            ? '${account.displayName} (${account.username}@${account.server})'
                            : '${account.username}@${account.server}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status badge & actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel(account),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isSelected)
                          _TinyAction(
                            icon: Icons.check_circle_outline,
                            color: AppTheme.accent,
                            onTap: () async {
                              await ref
                                  .read(accountServiceProvider)
                                  .setSelectedAccount(account.uuid);
                              ref.invalidate(accountsListProvider);
                            },
                          ),
                        _TinyAction(
                          icon: Icons.delete_outline,
                          color: AppTheme.errorRed.withValues(alpha: 0.7),
                          onTap: () async {
                            await ref
                                .read(accountServiceProvider)
                                .deleteAccount(account.uuid);
                            ref.invalidate(accountsListProvider);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TinyAction(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../forms/account_form.dart';
import '../widgets/account_tile.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.onSelect,
    required this.onToggleRegistration,
    required this.onCreateAccount,
  });

  final List<SipAccount> accounts;
  final String? selectedAccountId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onToggleRegistration;
  final Future<void> Function({
    required String label,
    required String username,
    required String authUsername,
    required String domain,
    required String displayName,
    required String password,
    required SipTransport transport,
    required bool tlsEnabled,
    required bool iceEnabled,
    required bool srtpEnabled,
    required String? outboundProxy,
    required String? stunServer,
    required String? turnServer,
    required int registerExpiresSeconds,
    required DtmfMode dtmfMode,
    required String? voicemailNumber,
    required List<String> codecs,
  })
  onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Accounts', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Registration state lives in the bridge. Passwords are stored in secure storage.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        ...accounts.map(
          (account) => AccountTile(
            account: account,
            selected: account.id == selectedAccountId,
            onTap: () => onSelect(account.id),
            onToggleRegistration: () => onToggleRegistration(account.id),
          ),
        ),
        const SizedBox(height: 24),
        Text('Add account', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        AccountForm(onCreateAccount: onCreateAccount),
      ],
    );
  }
}

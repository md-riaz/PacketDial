import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../core/account_service.dart';
import '../models/account_schema.dart';
import '../providers/engine_provider.dart';

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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AccountDialogBody(existing: existing),
    );
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

// ── Account Dialog ───────────────────────────────────────────────────────
class _AccountDialogBody extends ConsumerStatefulWidget {
  final AccountSchema? existing;
  const _AccountDialogBody({this.existing});

  @override
  ConsumerState<_AccountDialogBody> createState() => _AccountDialogBodyState();
}

class _AccountDialogBodyState extends ConsumerState<_AccountDialogBody> {
  final nameCtrl = TextEditingController();
  final displayCtrl = TextEditingController();
  final serverCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final authUserCtrl = TextEditingController();
  final domainCtrl = TextEditingController();
  final proxyCtrl = TextEditingController();
  final stunCtrl = TextEditingController();
  final turnCtrl = TextEditingController();

  String transport = 'udp';
  bool autoRegister = true;
  bool srtpEnabled = false;

  bool isRegistering = false;
  String? registrationError;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      nameCtrl.text = e.accountName;
      displayCtrl.text = e.displayName;
      serverCtrl.text = e.server;
      userCtrl.text = e.username;
      passCtrl.text = e.password;
      authUserCtrl.text = e.authUsername;
      domainCtrl.text = e.domain;
      proxyCtrl.text = e.sipProxy;
      transport = e.transport;
      stunCtrl.text = e.stunServer;
      turnCtrl.text = e.turnServer;
      autoRegister = e.autoRegister;
      srtpEnabled = e.srtpEnabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.existing == null ? Icons.person_add : Icons.edit,
              size: 18,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(widget.existing == null ? 'Add SIP Account' : 'Edit Account'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (registrationError != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.errorRed.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.errorRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          registrationError!,
                          style: TextStyle(
                              color: AppTheme.errorRed.withValues(alpha: 0.9),
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              // Section: Identity
              _sectionLabel('Identity'),
              TextField(
                controller: nameCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'Account Label (e.g. Work)',
                  hintText: 'My Office Number',
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: displayCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'Display Name (Optional)',
                  hintText: 'John Doe',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              // Section: Server
              _sectionLabel('Server'),
              TextField(
                controller: serverCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'SIP Server / Registrar',
                  hintText: 'sip.provider.com',
                  prefixIcon: Icon(Icons.dns_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: userCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: '1000',
                  prefixIcon: Icon(Icons.account_circle_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                enabled: !isRegistering,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Advanced Settings',
                    style:
                        TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                tilePadding: EdgeInsets.zero,
                iconColor: AppTheme.textTertiary,
                collapsedIconColor: AppTheme.textTertiary,
                children: [
                  TextField(
                    controller: authUserCtrl,
                    enabled: !isRegistering,
                    decoration: const InputDecoration(
                      labelText: 'Auth Username (Optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: domainCtrl,
                    enabled: !isRegistering,
                    decoration: const InputDecoration(
                      labelText: 'Domain (Optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: proxyCtrl,
                    enabled: !isRegistering,
                    decoration: const InputDecoration(
                      labelText: 'SIP Proxy (Optional)',
                      helperText: 'Outbound proxy address if required.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: transport,
                    decoration: const InputDecoration(labelText: 'Transport'),
                    dropdownColor: AppTheme.surfaceVariant,
                    items: const [
                      DropdownMenuItem(value: 'udp', child: Text('UDP')),
                      DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                      DropdownMenuItem(value: 'tls', child: Text('TLS')),
                    ],
                    onChanged: isRegistering
                        ? null
                        : (v) => setState(() => transport = v ?? 'udp'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: stunCtrl,
                    enabled: !isRegistering,
                    decoration: const InputDecoration(
                      labelText: 'STUN Server (Optional)',
                      helperText: 'For NAT traversal (e.g. stun.l.google.com)',
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-register on startup',
                    style:
                        TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                value: autoRegister,
                onChanged: isRegistering
                    ? null
                    : (v) => setState(() => autoRegister = v ?? true),
              ),
              // Registering indicator
              if (isRegistering) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              AppTheme.primary.withValues(alpha: 0.7)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Verifying SIP credentials…',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.primary)),
                          SizedBox(height: 2),
                          Text(
                            'This may take several seconds',
                            style: TextStyle(
                                fontSize: 10, color: AppTheme.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isRegistering ? null : () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppTheme.textTertiary)),
        ),
        FilledButton(
          onPressed: isRegistering
              ? null
              : () async {
                  final name = nameCtrl.text.trim();
                  final server = serverCtrl.text.trim();
                  final user = userCtrl.text.trim();
                  final pass = passCtrl.text;

                  if (name.isEmpty ||
                      server.isEmpty ||
                      user.isEmpty ||
                      pass.isEmpty) {
                    setState(() {
                      registrationError = 'Please fill in all required fields.';
                    });
                    return;
                  }

                  // Start registration attempt
                  setState(() {
                    isRegistering = true;
                    registrationError = null;
                  });

                  final result =
                      await ref.read(accountServiceProvider).tryRegister(
                            username: user,
                            password: pass,
                            server: server,
                            transport: transport,
                            domain: domainCtrl.text.trim(),
                            proxy: proxyCtrl.text.trim(),
                          );

                  if (!result.success) {
                    // Registration failed — stay open
                    if (mounted) {
                      setState(() {
                        isRegistering = false;
                        registrationError = result.errorReason ??
                            'Registration failed. Check your credentials.';
                      });
                    }
                    return;
                  }

                  // Registration succeeded — save the account
                  final schema = AccountSchema()
                    ..id = widget.existing?.id
                    ..uuid = widget.existing?.uuid ?? ''
                    ..accountName = name
                    ..displayName = displayCtrl.text.trim()
                    ..server = server
                    ..sipProxy = proxyCtrl.text.trim()
                    ..username = user
                    ..authUsername = authUserCtrl.text.trim()
                    ..domain = domainCtrl.text.trim()
                    ..password = pass
                    ..transport = transport
                    ..stunServer = stunCtrl.text.trim()
                    ..turnServer = turnCtrl.text.trim()
                    ..tlsEnabled = (transport == 'tls')
                    ..srtpEnabled = srtpEnabled
                    ..autoRegister = autoRegister
                    ..isSelected = widget.existing?.isSelected ?? false;

                  await ref.read(accountServiceProvider).saveAccount(schema);

                  // Re-register with the real (saved) UUID so the account
                  // stays active — the trial registration used a temp UUID
                  // that was already cleaned up.
                  ref.read(accountServiceProvider).register(schema);

                  ref.invalidate(accountsListProvider);
                  if (context.mounted) Navigator.pop(context);
                },
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save Account'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                letterSpacing: 1,
              )),
        ],
      ),
    );
  }
}
